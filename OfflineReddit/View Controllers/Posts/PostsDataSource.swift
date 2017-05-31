//
//  PostsDataSource.swift
//  OfflineReddit
//
//  Created by Jake Bellamy on 6/05/17.
//  Copyright © 2017 Jake Bellamy. All rights reserved.
//

import UIKit
import BoltsSwift
import Dwifft

class PostsDataSource: NSObject {
    
    weak var tableView: UITableView?
    
    var subreddits: [Subreddit] = [] {
        didSet { allRows.removeAll() }
    }
    
    var commentsSort = Defaults.commentsSort
    
    // MARK: - Init
    
    let postsProvider: PostsProvider
    let subredditsProvider: SubredditsProvider
    
    init(provider: DataProvider) {
        self.postsProvider = PostsProvider(provider: provider)
        self.subredditsProvider = SubredditsProvider(provider: provider)
    }
    
    // MARK: - Rows
    
    /// Master list of all posts available to display, before filtering.
    var allRows: [PostCellModel] = []
    
    /// List of posts which drives the table view. Is a subset of `rows` when `sort.shouldFilter == true`, otherwise equals `allRows`.
    private(set) var rows: [PostCellModel] = []
    
    var sort = Defaults.postsSortFilter {
        didSet { animateRowsUpdate() }
    }
    
    func post(at indexPath: IndexPath) -> Post {
        return rows[indexPath.row].post
    }
    
    func indexPath(for post: Post) -> IndexPath? {
        return rows
            .index { $0.post == post }
            .map { IndexPath(row: $0, section: 0) }
    }
    
    private func animateRowsUpdate() {
        tableView?.reload(get: { self.rows }, update: updateRows)
    }
    
    private func updateRows() {
        rows = allRows.sortFiltered(using: sort)
    }
    
    func processPostChanges(at indexPath: IndexPath) {
        let post = self.post(at: indexPath)
        let shouldRemove = ( post.isRead && !sort.filter.contains(.read))
            ||             (!post.isRead && !sort.filter.contains(.notRead))
        if shouldRemove {
            rows.remove(at: indexPath.row)
            tableView?.deleteRows(at: [indexPath], with: .fade)
        } else {
            update(
                cell: tableView?.cellForRow(at: indexPath) as? PostCell,
                isAvailableOffline: post.isAvailableOffline
            )
        }
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
    
    func fetchNextPage() -> Task<[Post]> {
        guard !subreddits.isEmpty else { return Task<[Post]>([]) }
        return postsProvider.getPosts(for: subreddits, after: rows.last?.post, sortedBy: sort.sort, period: sort.period)
            .continueOnSuccessWith(.mainThread) { posts -> [Post] in
                if !posts.isEmpty {
                    self.allRows += posts.map(PostCellModel.init)
                    self.animateRowsUpdate()
                }
                return posts
        }
    }
    
    func reloadWithOfflinePosts() -> Task<[Post]> {
        return postsProvider.getAllOfflinePosts(for: subreddits, sortedBy: sort.sort, period: sort.period)
            .continueOnSuccessWith(.mainThread) { posts -> [Post] in
                self.allRows = posts.map(PostCellModel.init)
                self.animateRowsUpdate()
                self.tableView?.reloadData()
                return posts
        }
    }
    
    // MARK: Offline saving
    
    private(set) var downloader: PostsDownloader?
    
    @discardableResult
    func startDownload(for indexPaths: [IndexPath]) -> Task<[Post]> {
        let downloader = PostsDownloader(posts: indexPaths.map(post(at:)), remote: postsProvider.remote, commentsSort: commentsSort)
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
                self.postsProvider.local.trySave()
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
