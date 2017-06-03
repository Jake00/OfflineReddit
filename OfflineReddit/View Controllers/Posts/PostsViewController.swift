//
//  PostsViewController.swift
//  OfflineReddit
//
//  Created by Jake Bellamy on 19/03/17.
//  Copyright © 2017 Jake Bellamy. All rights reserved.
//

import UIKit
import BoltsSwift

class PostsViewController: UIViewController, Loadable {
    
    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var loadMoreButton: UIButton!
    @IBOutlet weak var activityIndicator: UIActivityIndicatorView!
    @IBOutlet weak var activityIndicatorCenterX: NSLayoutConstraint!
    @IBOutlet weak var hintLabel: UILabel!
    @IBOutlet weak var hintImage: UIImageView!
    @IBOutlet var footerView: UIView!
    @IBOutlet var subredditsButton: UIBarButtonItem!
    @IBOutlet var chooseDownloadsButton: UIBarButtonItem!
    @IBOutlet var startDownloadsButton: UIBarButtonItem!
    @IBOutlet var cancelDownloadsButton: UIBarButtonItem!
    @IBOutlet var filterButton: UIBarButtonItem!
    
    let dataSource: PostsDataSource
    let reachability: Reachability
    
    // MARK: - Init
    
    init(provider: DataProvider) {
        self.dataSource = PostsDataSource(provider: provider)
        self.reachability = provider.reachability
        super.init(nibName: String(describing: PostsViewController.self), bundle: nil)
    }
    
    @available(*, unavailable, message: "init(coder:) is not available. Use init(provider:) instead.")
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) is not available. Use init(provider:) instead.")
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    // MARK: - View controller
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        dataSource.tableView = tableView
        tableView.rowHeight = UITableViewAutomaticDimension
        tableView.estimatedRowHeight = 50
        tableView.dataSource = dataSource
        tableView.tableFooterView = footerView
        tableView.registerReusableNibCell(PostCell.self)
        toolbarItems = [
            UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil),
            filterButton
        ]
        
        NotificationCenter.default.addObserver(self, selector: #selector(reachabilityChanged(_:)), name: .ReachabilityChanged, object: nil)
        
        updateNavigationItemButtons()
        fetchInitial()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        updateSelectedRow()
        if navigationController?.isToolbarHidden ?? false {
            navigationController?.setToolbarHidden(false, animated: animated)
        }
    }
    
    override func setEditing(_ editing: Bool, animated: Bool) {
        super.setEditing(editing, animated: animated)
        tableView.setEditing(editing, animated: true)
        tableView.beginUpdates()
        tableView.endUpdates()
        updateStartDownloadsButtonEnabled()
        updateNavigationItemButtons(animated: animated)
    }
    
    // MARK: - Navigation
    
    func showCommentsViewController(post: Post) {
        let provider = DataProvider(remote: dataSource.postsProvider.remote, local: dataSource.postsProvider.local, reachability: reachability)
        let commentsViewController = CommentsViewController(post: post, provider: provider)
        navigationController?.pushViewController(commentsViewController, animated: true)
    }
    
    func showSubredditsViewController() {
        let provider = DataProvider(remote: dataSource.postsProvider.remote, local: dataSource.postsProvider.local, reachability: reachability)
        let subredditsViewController = SubredditsViewController(provider: provider)
        subredditsViewController.didSelectSubreddits = { [weak self] in
            self?.dataSource.subreddits = $0
            self?.updateFooterView()
            self?.fetchNextPageOrReloadIfOffline()
        }
        navigationController?.pushViewController(subredditsViewController, animated: true)
        navigationController?.setToolbarHidden(true, animated: true)
    }
    
    func showFilterPostsViewController() {
        let filterPostsViewController = FilterPostsViewController(reachability: reachability)
        filterPostsViewController.dataSource.selected = dataSource.sort
        filterPostsViewController.didUpdate = { [unowned self] sort in
            let change = Post.SortFilterChange(old: self.dataSource.sort, new: sort)
            self.dataSource.sort = sort
            if change.didChangeOfflineFilter {
                self.fetchNextPageOrReloadIfOffline()
            }
        }
        navigationController?.pushViewController(filterPostsViewController, animated: true)
        navigationController?.setToolbarHidden(true, animated: true)
    }
    
    // MARK: - Fetching
    
    var isLoading = false {
        didSet {
            updateChooseDownloadsButtonEnabled()
            guard reachability.isOnline else { return }
            loadMoreButton.isEnabled = !isLoading
            loadMoreButton.titleEdgeInsets.left = isLoading ? -activityIndicatorCenterX.constant : 0
            activityIndicator.setAnimating(isLoading)
        }
    }
    
    @discardableResult
    func fetchInitial() -> Task<Void> {
        return fetch(dataSource.subredditsProvider.getAllSelectedSubreddits())
            .continueOnSuccessWithTask { subreddits -> Task<Void> in
                self.dataSource.subreddits = subreddits
                self.updateFooterView()
                if self.reachability.isOffline {
                    self.dataSource.sort.filter.remove(.online)
                }
                return self.fetchNextPageOrReloadIfOffline()
        }
    }
    
    @discardableResult
    func fetchNextPageOrReloadIfOffline() -> Task<Void> {
        let task = reachability.isOnline && dataSource.sort.filter.contains(.online)
            ? dataSource.fetchNextPage()
            : dataSource.reloadWithOfflinePosts()
        return fetch(task).continueOnSuccessWith(.immediate) { _ in }
    }
    
    // MARK: - UI Updating
    
    func updateFooterView() {
        let hideHints = !dataSource.subreddits.isEmpty
        hintLabel.isHidden = hideHints
        hintImage.isHidden = hideHints
        loadMoreButton.isHidden = !hideHints
        loadMoreButton.isEnabled = reachability.isOnline
        loadMoreButton.setTitle(reachability.isOnline ? SharedText.loadingLowercase : SharedText.offline, for: .disabled)
        activityIndicator.setAnimating(hideHints && isLoading)
    }
    
    func updateNavigationItemButtons(animated: Bool = false) {
        navigationItem.setRightBarButtonItems(isEditing ? [cancelDownloadsButton, startDownloadsButton] : [subredditsButton], animated: animated)
        navigationItem.setLeftBarButtonItems(isEditing ? nil : [chooseDownloadsButton], animated: animated)
    }
    
    func updateStartDownloadsButtonEnabled() {
        startDownloadsButton.isEnabled = tableView.indexPathsForSelectedRows?.isEmpty == false
    }
    
    func updateChooseDownloadsButtonEnabled() {
        chooseDownloadsButton.isEnabled = !dataSource.rows.isEmpty && !isSavingOffline && reachability.isOnline
    }
    
    func updateSelectedRow() {
        guard let selectedIndexPath = tableView.indexPathForSelectedRow else { return }
        dataSource.processPostChanges(at: selectedIndexPath)
        tableView.deselectRow(at: selectedIndexPath, animated: true)
    }
    
    // MARK: - Posts downloading
    
    var isSavingOffline: Bool {
        return dataSource.downloader != nil
    }
    
    @discardableResult
    func startPostsDownload(for indexPaths: [IndexPath]) -> Task<Void> {
        let task = fetch(dataSource.startDownload(for: indexPaths))
            .continueWith(.mainThread) { _ in
                self.navigationBarProgressView?.observedProgress = nil
                self.navigationBarProgressView?.isHidden = true
                self.updateChooseDownloadsButtonEnabled()
                UIView.animate(withDuration: 0.4) {
                    self.tableView.layoutIfNeeded()
                    self.tableView.beginUpdates()
                    self.tableView.endUpdates()
                }
        }
        setEditing(false, animated: true)
        updateChooseDownloadsButtonEnabled()
        navigationBarProgressView?.isHidden = false
        navigationBarProgressView?.setProgress(0, animated: false)
        navigationBarProgressView?.observedProgress = dataSource.downloader?.progress
        return task
    }
    
    // MARK: - Reachablity
    
    func reachabilityChanged(_ notification: Notification) {
        updateFooterView()
        updateChooseDownloadsButtonEnabled()
        if reachability.isOffline {
            if isEditing {
                setEditing(false, animated: true)
            }
            dataSource.sort.filter.remove(.online)
        } else {
            dataSource.sort.filter.insert(.online)
        }
        fetchNextPageOrReloadIfOffline()
    }
    
    // MARK: - UI Actions
    
    @IBAction func chooseDownloadButtonPressed(_ sender: UIBarButtonItem) {
        setEditing(true, animated: true)
    }
    
    @IBAction func startDownloadsButtonPressed(_ sender: UIBarButtonItem) {
        if isEditing, let indexPaths = tableView.indexPathsForSelectedRows, !indexPaths.isEmpty {
            startPostsDownload(for: indexPaths)
        } else {
            setEditing(!isEditing, animated: true); return
        }
    }

    @IBAction func cancelDownloadsButtonPressed(_ sender: UIBarButtonItem) {
        setEditing(false, animated: true)
    }
    
    @IBAction func loadMoreButtonPressed(_ sender: UIButton) {
        if !isLoading && !isSavingOffline {
            fetchNextPageOrReloadIfOffline()
        }
    }
    
    @IBAction func showSubredditsButtonPressed(_ sender: UIButton) {
        showSubredditsViewController()
    }
    
    @IBAction func filterButtonPressed(_ sender: UIBarButtonItem) {
        showFilterPostsViewController()
    }
}

// MARK: - Table view delegate

extension PostsViewController: UITableViewDelegate {
    
    func tableView(_ tableView: UITableView, shouldHighlightRowAt indexPath: IndexPath) -> Bool {
        return !isSavingOffline && (indexPath.row != dataSource.rows.endIndex || !isLoading)
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if isEditing {
            updateStartDownloadsButtonEnabled()
        } else {
            showCommentsViewController(post: dataSource.post(at: indexPath))
        }
    }
    
    func tableView(_ tableView: UITableView, didDeselectRowAt indexPath: IndexPath) {
        if isEditing {
            updateStartDownloadsButtonEnabled()
        }
    }
}
