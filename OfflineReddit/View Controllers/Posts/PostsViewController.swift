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
    @IBOutlet var filterButton: UIBarButtonItem!
    @IBOutlet weak var downloadPostsHeader: UIView!
    @IBOutlet weak var downloadPostsBackgroundView: UIToolbar!
    @IBOutlet weak var downloadPostsSlider: UISlider!
    @IBOutlet weak var downloadPostsTitleLabel: UILabel!
    @IBOutlet weak var downloadPostsCancelButton: UIButton!
    @IBOutlet weak var downloadPostsSaveButton: UIButton!
    @IBOutlet var downloadPostsHeaderShowing: NSLayoutConstraint!
    @IBOutlet var downloadPostsHeaderHiding: NSLayoutConstraint!
    
    var isLoading = false {
        didSet {
            updateChooseDownloadsButtonEnabled()
            guard reachability.isOnline else { return }
            loadMoreButton.isEnabled = !isLoading
            loadMoreButton.titleEdgeInsets.left = isLoading ? -activityIndicatorCenterX.constant : 0
            activityIndicator.setAnimating(isLoading)
        }
    }
    
    /// When using the slider to select posts to download, its maximum value intentionally
    /// includes more rows than is displayed in the table view. This value keeps track of 
    /// the overflow in order to download the additional posts on the next pages.
    var futurePostsToDownload = 0
    
    var undoPostProcessing: PostsDataSource.UndoPostProcessing?
    
    let dataSource: PostsDataSource
    let reachability: Reachability
    
    // MARK: - Init
    
    init(dataSource: PostsDataSource) {
        self.dataSource = dataSource
        self.reachability = dataSource.reachability
        super.init(nibName: String(describing: PostsViewController.self), bundle: nil)
    }
    
    convenience init(provider: DataProvider) {
        self.init(dataSource: PostsDataSource(provider: provider))
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
        dataSource.delegate = self
        tableView.rowHeight = UITableViewAutomaticDimension
        tableView.estimatedRowHeight = 50
        tableView.dataSource = dataSource
        tableView.tableFooterView = footerView
        tableView.registerReusableNibCell(PostCell.self)
        toolbarItems = [
            UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil),
            filterButton
        ]
        navigationItem.leftBarButtonItem = chooseDownloadsButton
        navigationItem.rightBarButtonItem = subredditsButton
        automaticallyAdjustsScrollViewInsets = false
        enableDynamicType()
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(reachabilityChanged(_:)),
            name: .ReachabilityChanged,
            object: nil)
        
        updateSelectedRowsToDownload(updateSlider: true)
        dataSource.fetchInitial().continueWith(.mainThread) { _ in
            self.updateFooterView()
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        updateSelectedRow()
        if navigationController?.isToolbarHidden ?? false {
            navigationController?.setToolbarHidden(false, animated: animated)
        }
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        reselectRowIfNeeded()
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        tableView.contentInset = UIEdgeInsets(
            top: isEditing ? downloadPostsHeader.frame.height : topLayoutGuide.length,
            left: 0,
            bottom: bottomLayoutGuide.length,
            right: 0)
        tableView.scrollIndicatorInsets = tableView.contentInset
    }
    
    override func setEditing(_ editing: Bool, animated: Bool) {
        super.setEditing(editing, animated: animated)
        tableView.setEditing(editing, animated: true)
        tableView.beginUpdates()
        tableView.endUpdates()
        futurePostsToDownload = 0
        updateStartDownloadsButtonEnabled()
        navigationController?.setToolbarHidden(editing, animated: animated)
        setDownloadPostsHeaderVisible(editing, animated: animated)
        if !editing {
            updateSelectedRowsToDownload(updateSlider: true)
        }
    }
    
    // MARK: - Navigation
    
    func showCommentsViewController(post: Post) {
        let provider = DataProvider(
            remote: dataSource.postsProvider.remote,
            local: dataSource.postsProvider.local,
            reachability: reachability)
        let commentsViewController = CommentsViewController(post: post, provider: provider)
        navigationController?.pushViewController(commentsViewController, animated: true)
    }
    
    func showSubredditsViewController() {
        let provider = DataProvider(
            remote: dataSource.postsProvider.remote,
            local: dataSource.postsProvider.local,
            reachability: reachability)
        let subredditsViewController = SubredditsViewController(provider: provider)
        subredditsViewController.didSelectSubreddits = { [weak self] in
            self?.dataSource.subreddits = $0
            self?.updateFooterView()
            self?.dataSource.fetchNextPageOrReloadIfOffline()
        }
        navigationController?.pushViewController(subredditsViewController, animated: true)
        navigationController?.setToolbarHidden(true, animated: true)
    }
    
    func showFilterPostsViewController() {
        let filterPostsViewController = FilterPostsViewController(reachability: reachability)
        filterPostsViewController.dataSource.selected = dataSource.sort
        filterPostsViewController.didUpdate = { [weak self] sort in
            self?.dataSource.sort = sort
        }
        navigationController?.pushViewController(filterPostsViewController, animated: true)
        navigationController?.setToolbarHidden(true, animated: true)
    }
    
    // MARK: - Posts downloading
    
    var isSavingOffline: Bool {
        return dataSource.downloader != nil
    }
    
    @discardableResult
    func startPostsDownload(for indexPaths: [IndexPath], additional: Int) -> Task<Void> {
        let task = dataSource.startDownload(for: indexPaths, additional: additional)
            .continueWith(.mainThread) { _ in
                self.navigationBarProgressView?.observedProgress = nil
                self.navigationBarProgressView?.isHidden = true
                UIView.animate(withDuration: 0.4) {
                    self.tableView.layoutIfNeeded()
                    self.tableView.beginUpdates()
                    self.tableView.endUpdates()
                }
        }
        setEditing(false, animated: true)
        navigationBarProgressView?.isHidden = false
        navigationBarProgressView?.setProgress(0, animated: false)
        navigationBarProgressView?.observedProgress = dataSource.downloader?.progress
        return fetch(task)
    }
    
    // MARK: - Reachablity
    
    func reachabilityChanged(_ notification: Notification) {
        updateFooterView()
        updateChooseDownloadsButtonEnabled()
        if reachability.isOffline, isEditing {
            setEditing(false, animated: true)
        }
    }
}

// MARK: - Table view delegate

extension PostsViewController: UITableViewDelegate {
    
    func tableView(_ tableView: UITableView, shouldHighlightRowAt indexPath: IndexPath) -> Bool {
        return !isSavingOffline && (indexPath.row != dataSource.rows.endIndex || !isLoading)
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if isEditing {
            updateSelectedRowsToDownload(updateSlider: true)
        } else {
            showCommentsViewController(post: dataSource.post(at: indexPath))
        }
    }
    
    func tableView(_ tableView: UITableView, didDeselectRowAt indexPath: IndexPath) {
        if isEditing {
            updateSelectedRowsToDownload(updateSlider: true)
        }
    }
}

// MARK: - Data source delegate

extension PostsViewController: PostsDataSourceDelegate {
    
    func postsDataSource(_ dataSource: PostsDataSource, isFetchingWith task: Task<Void>) {
        fetch(task)
    }
}
