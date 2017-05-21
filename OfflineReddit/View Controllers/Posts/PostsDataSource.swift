//
//  PostsDataSource.swift
//  OfflineReddit
//
//  Created by Jake Bellamy on 6/05/17.
//  Copyright © 2017 Jake Bellamy. All rights reserved.
//

import UIKit
import BoltsSwift

class PostsDataSource: NSObject {
    
    weak var tableView: UITableView?
    
    var subreddits: [Subreddit] = [] {
        didSet { rows.removeAll() }
    }
    
    // MARK: - Init
    
    let provider: PostsProvider
    
    init(provider: DataProvider) {
        self.provider = PostsProvider(provider: provider)
    }
    
    // MARK: - Rows
    
    var rows: [PostCellModel] = []
    
    func post(at indexPath: IndexPath) -> Post {
        return rows[indexPath.row].post
    }
    
    func indexPath(for post: Post) -> IndexPath? {
        return rows
            .index { $0.post == post }
            .map { IndexPath(row: $0, section: 0) }
    }
    
    // MARK: - Updating cells
    
    func updateAll(cell: PostCell?, row: PostCellModel) {
        updateText(cell: cell, post: row.post)
        update(cell: cell, state: row.state)
        update(cell: cell, isAvailableOffline: row.post.isAvailableOffline)
    }
    
    func updateText(cell: PostCell?, post: Post) {
        cell?.topLabel.text = post.subredditAuthorTimeText
        cell?.titleLabel.text = post.title
        cell?.bottomLabel.text = post.scoreCommentsText
    }
    
    func update(cell: PostCell?, state: PostCellModel.State) {
        cell?.containerLeading.constant = state == .normal ? 0 : PostCellModel.indentedWidth
        cell?.activityIndicator.setAnimating(state == .loading)
        cell?.checkedImageView.isHidden = state != .checked
    }
    
    func update(cell: PostCell?, isAvailableOffline: Bool) {
        cell?.offlineImageView.isHidden = !isAvailableOffline
    }
    
    func updateIsAvailableOffline(for posts: [Post]) {
        guard let tableView = tableView else { return }
        for post in posts {
            let cell = indexPath(for: post).flatMap(tableView.cellForRow(at:))
            update(cell: cell as? PostCell, isAvailableOffline: post.isAvailableOffline)
        }
    }
    
    // MARK: - Set models
    
    func setState(_ state: PostCellModel.State, at indexPath: IndexPath) {
        let cell = tableView?.cellForRow(at: indexPath) as? PostCell
        rows[indexPath.row].state = state
        update(cell: cell, state: state)
    }
    
    func setState(_ state: PostCellModel.State, at indexPaths: [IndexPath]) {
        for indexPath in indexPaths {
            setState(state, at: indexPath)
        }
    }
    
    func setState(_ state: PostCellModel.State, for post: Post) {
        if let (row, _) = rows.enumerated().first(where: { $0.1.post == post }) {
            setState(state, at: IndexPath(row: row, section: 0))
        }
    }
    
    func setAllStates(to state: PostCellModel.State) {
        let indexPaths = (0..<rows.count).map { IndexPath(row: $0, section: 0) }
        setState(state, at: indexPaths)
    }
    
    func setIsAvailableOffline(_ isAvailableOffline: Bool, at indexPath: IndexPath) {
        post(at: indexPath).isAvailableOffline = isAvailableOffline
        let cell = tableView?.cellForRow(at: indexPath) as? PostCell
        update(cell: cell, isAvailableOffline: isAvailableOffline)
    }
    
    // MARK: - Fetching
    
    func fetchInitial() -> Task<Void> {
        return provider.getAllSelectedSubreddits()
            .continueOnSuccessWithTask(.mainThread) { _ -> Task<[Post]> in
                self.tableView?.reloadData()
                return self.fetchNextPage()
            }.continueOnSuccessWith(.immediate) { _ -> Void in }
    }
    
    func fetchNextPage() -> Task<[Post]> {
        guard !subreddits.isEmpty else { return Task<[Post]>([]) }
        return provider.getPosts(for: subreddits, after: rows.last?.post)
            .continueOnSuccessWith(.mainThread) { posts -> [Post] in
                guard !posts.isEmpty else { return posts }
                let new = posts.map(PostCellModel.init)
                self.tableView?.beginUpdates()
                self.rows += new
                let indexPaths = (self.rows.count - new.count..<self.rows.count)
                    .map { IndexPath(row: $0, section: 0) }
                self.tableView?.insertRows(at: indexPaths, with: .fade)
                self.tableView?.endUpdates()
                return posts
        }
    }
    
    func reloadWithOfflinePosts() -> Task<[Post]> {
        return provider.getAllOfflinePosts(for: subreddits)
            .continueOnSuccessWith(.mainThread) { posts -> [Post] in
                self.rows = posts.map(PostCellModel.init)
                self.tableView?.reloadData()
                return posts
        }
    }
    
    // MARK: Offline saving
    
    private(set) var downloader: PostsDownloader?
    
    @discardableResult
    func startDownload(for indexPaths: [IndexPath]) -> Task<[Post]> {
        let downloader = PostsDownloader(posts: indexPaths.map(post(at:)), remote: provider.remote)
        downloader.completionForPost = { post in
            self.setState(.checked, for: post)
        }
        self.downloader = downloader
        setAllStates(to: .indented)
        setState(.loading, at: indexPaths)
        return downloader.start()
            .continueWithTask(.mainThread) { task -> Task<[Post]> in
                self.downloader = nil
                if let posts = task.result {
                    self.updateIsAvailableOffline(for: posts)
                }
                self.setAllStates(to: .normal)
                self.provider.local.trySave()
                return task
        }
    }
    
}

// MARK: - Table view data source

extension PostsDataSource: UITableViewDataSource {

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return rows.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell: PostCell = tableView.dequeueReusableCell(for: indexPath)
        updateAll(cell: cell, row: rows[indexPath.row])
        cell.setNeedsLayout()
        cell.layoutIfNeeded()
        return cell
    }
}
