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

protocol PostsDataSourceDelegate: class {
    func postsDataSource(_ dataSource: PostsDataSource, isFetchingWith task: Task<Void>)
}

class PostsDataSource: NSObject {
    
    weak var tableView: UITableView?
    weak var delegate: PostsDataSourceDelegate?
    
    var subreddits: [Subreddit] = [] {
        didSet {
            allRows.removeAll()
            rows.removeAll()
            tableView?.reloadData()
        }
    }
    
    // MARK: - Init
    
    let postsProvider: PostsProvider
    let subredditsProvider: SubredditsProvider
    let reachability: Reachability
    
    init(provider: DataProvider) {
        self.postsProvider = PostsProvider(provider: provider)
        self.subredditsProvider = SubredditsProvider(provider: provider)
        self.reachability = provider.reachability
        super.init()
        NotificationCenter.default.addObserver(self, selector: #selector(reachabilityChanged(_:)), name: .ReachabilityChanged, object: nil)
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    // MARK: - Rows
    
    /// Master list of all posts available to display, before filtering.
    var allRows: Set<PostCellModel> = []
    
    /// List of posts which drives the table view. Is a subset of `rows` when `sort.shouldFilter == true`, otherwise equals `allRows`.
    private(set) var rows: [PostCellModel] = []
    
    var sort = Defaults.postsSortFilter {
        didSet { updateSort(old: oldValue) }
    }
    
    func post(at indexPath: IndexPath) -> Post {
        return rows[indexPath.row].post
    }
    
    func indexPath(for post: Post) -> IndexPath? {
        return rows
            .index { $0.post == post }
            .map { IndexPath(row: $0, section: 0) }
    }
    
    private func updateSort(old: Post.SortFilter) {
        let change = Post.SortFilterChange(old: old, new: sort)
        
        if change.didSelectOffline {
            reloadWithOfflinePosts()
        } else if change.didSelectOnline, allRows.contains(where: { !$0.post.isAvailableOffline }) {
            fetchNextPage()
        } else {
            animateRowsUpdate()
        }
    }
    
    private func animateRowsUpdate() {
        tableView?.reload(get: { rows }, update: updateRows)
    }
    
    func updateRows() {
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
    
    func fetch<T>(_ task: Task<T>) -> Task<T> {
        delegate?.postsDataSource(self, isFetchingWith: task.asVoid())
        return task
    }
    
    @discardableResult
    func fetchInitial() -> Task<Void> {
        return fetch(subredditsProvider.getAllSelectedSubreddits())
            .continueOnSuccessWithTask { subreddits -> Task<Void> in
                self.subreddits = subreddits
                if self.reachability.isOffline {
                    self.sort.filter.remove(.online)
                }
                return self.fetchNextPageOrReloadIfOffline().asVoid()
        }
    }
    
    @discardableResult
    func fetchNextPageOrReloadIfOffline() -> Task<[Post]> {
        let task = reachability.isOnline && sort.filter.contains(.online)
            ? fetchNextPage()
            : reloadWithOfflinePosts()
        return fetch(task)
    }
    
    @discardableResult
    func fetchNextPage(addingModelsWithState state: PostCellModel.State = .normal) -> Task<[Post]> {
        guard !subreddits.isEmpty else { return Task<[Post]>([]) }
        return fetch(postsProvider.getPosts(for: subreddits, after: rows.last?.post, sortedBy: sort.sort, period: sort.period)
            .continueOnSuccessWith(.mainThread) { posts -> [Post] in
                if !posts.isEmpty {
                    self.allRows.formUnion(posts.map { PostCellModel(post: $0, state: state) })
                    self.animateRowsUpdate()
                }
                return posts
        })
    }
    
    @discardableResult
    func reloadWithOfflinePosts() -> Task<[Post]> {
        return fetch(postsProvider.getAllOfflinePosts(for: subreddits, sortedBy: sort.sort, period: sort.period)
            .continueOnSuccessWith(.mainThread) { posts -> [Post] in
                self.allRows = Set(posts.map(PostCellModel.init))
                self.animateRowsUpdate()
                self.tableView?.reloadData()
                return posts
        })
    }
    
    // MARK: - Offline saving
    
    private(set) var downloader: PostsDownloader?
    var downloadingCommentsSort = Defaults.commentsSort
    
    @discardableResult
    func startDownload(for indexPaths: [IndexPath], additional: Int) -> Task<[Post]> {
        var additional = additional
        setAllStates(to: .indented)
        setState(.loading, at: indexPaths)
        
        let downloader = PostsDownloader(remote: postsProvider.remote, commentsSort: downloadingCommentsSort)
        downloader.completionForPost = { post in
            self.setState(.checked, for: post)
        }
        downloader.posts = indexPaths.map(post(at:))
        self.downloader = downloader
        
        func fetchNextPageOrStartDownload() -> Task<[Post]> {
            guard additional > 0 else {
                return downloader.start()
            }
            return fetchNextPage(addingModelsWithState: .indented)
                .continueOnSuccessWithTask { page in
                    let newPosts = self.rows.filter { $0.state == .indented }
                        .prefix(additional).map { $0.post }
                    downloader.posts += newPosts
                    additional -= newPosts.count
                    self.setState(.loading, at: newPosts.flatMap(self.indexPath(for:)))
                    return fetchNextPageOrStartDownload()
            }
        }
        return fetch(fetchNextPageOrStartDownload()
            .continueWithTask(.mainThread) { task in
                self.downloader = nil
                if let posts = task.result {
                    self.updateIsAvailableOffline(for: posts)
                }
                self.setAllStates(to: .normal)
                self.postsProvider.local.trySave()
                return task
        })
    }
    
    // MARK: - Reachability
    
    func reachabilityChanged(_ notification: Notification) {
        if reachability.isOffline {
            sort.filter.remove(.online)
        } else {
            sort.filter.insert(.online)
        }
        animateRowsUpdate()
        fetchNextPageOrReloadIfOffline()
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
