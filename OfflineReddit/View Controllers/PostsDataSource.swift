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
    
    var rows: [PostCellModel] = []
    var subreddits: [Subreddit] = [] {
        didSet { rows.removeAll() }
    }
    
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
    
    func updateIsAvailableOffline(for posts: [Post], in tableView: UITableView) {
        for post in posts {
            let cell = indexPath(for: post).flatMap(tableView.cellForRow(at:))
            update(cell: cell as? PostCell, isAvailableOffline: post.isAvailableOffline)
        }
    }
    
    // MARK: - Set models
    
    func setState(_ state: PostCellModel.State, at indexPath: IndexPath, in tableView: UITableView) {
        let cell = tableView.cellForRow(at: indexPath) as? PostCell
        rows[indexPath.row].state = state
        update(cell: cell, state: state)
    }
    
    func setState(_ state: PostCellModel.State, at indexPaths: [IndexPath], in tableView: UITableView) {
        for indexPath in indexPaths {
            setState(state, at: indexPath, in: tableView)
        }
    }
    
    func setState(_ state: PostCellModel.State, for post: Post, in tableView: UITableView) {
        if let (row, _) = rows.enumerated().first(where: { $0.1.post == post }) {
            setState(state, at: IndexPath(row: row, section: 0), in: tableView)
        }
    }
    
    func setAllStates(to state: PostCellModel.State, in tableView: UITableView) {
        let indexPaths = (0..<rows.count).map { IndexPath(row: $0, section: 0) }
        setState(state, at: indexPaths, in: tableView)
    }
    
    func setIsAvailableOffline(_ isAvailableOffline: Bool, at indexPath: IndexPath, in tableView: UITableView) {
        post(at: indexPath).isAvailableOffline = isAvailableOffline
        let cell = tableView.cellForRow(at: indexPath) as? PostCell
        update(cell: cell, isAvailableOffline: isAvailableOffline)
    }
    
    // MARK: - Fetching
    
    lazy var provider = DataProvider.shared
    
    func fetchNextPage(updating tableView: UITableView) -> Task<[Post]> {
        let get = provider.getPosts(for: subreddits, after: rows.last?.post)
        return get.continueOnSuccessWith(.mainThread) { posts, context -> [Post] in
            let new = posts.map(PostCellModel.init)
            switch context {
            case .replace:
                self.rows = new
                tableView.reloadData()
            case .append where !new.isEmpty:
                self.rows += new
                let indexPaths = (self.rows.count - new.count..<self.rows.count)
                    .map { IndexPath(row: $0, section: 0) }
                tableView.insertRowsSafe(at: indexPaths, with: .fade)
            default: ()
            }
            return posts
        }
    }
    
    func updateSelectedSubreddits() -> Task<Void> {
        return provider.getSelectedSubreddits()
            .continueOnSuccessWith { self.subreddits = $0 }
    }
    
    // MARK: Offline saving
    
    private(set) var downloader: PostsDownloader?
    
    @discardableResult
    func startDownload(for indexPaths: [IndexPath], updating tableView: UITableView) -> Task<[Post]> {
        let downloader = PostsDownloader(posts: indexPaths.map(post(at:)), remote: provider.remote)
        downloader.completionForPost = { post in
            self.setState(.checked, for: post, in: tableView)
        }
        self.downloader = downloader
        return downloader.start()
            .continueWithTask(.mainThread) { task -> Task<[Post]> in
                self.downloader = nil
                if let posts = task.result {
                    self.updateIsAvailableOffline(for: posts, in: tableView)
                }
                self.setAllStates(to: .normal, in: tableView)
                self.provider.save()
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
        let cell = tableView.dequeueReusableCell(withIdentifier: "Post", for: indexPath) as! PostCell
        updateAll(cell: cell, row: rows[indexPath.row])
        cell.setNeedsLayout()
        cell.layoutIfNeeded()
        return cell
    }
}
