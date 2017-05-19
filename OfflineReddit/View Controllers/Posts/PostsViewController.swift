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
    
    let dataSource = PostsDataSource()
    lazy var reachability: Reachable = Reachability.shared
    
    // MARK: - Init
    
    override init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: Bundle?) {
        super.init(nibName: String(describing: PostsViewController.self), bundle: nil)
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    // MARK: - View controller
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        tableView.rowHeight = UITableViewAutomaticDimension
        tableView.estimatedRowHeight = 50
        tableView.dataSource = dataSource
        tableView.tableFooterView = footerView
        tableView.register(UINib(nibName: String(describing: PostCell.self), bundle: nil), forCellReuseIdentifier: String(describing: PostCell.self))
        
        NotificationCenter.default.addObserver(self, selector: #selector(reachabilityChanged(_:)), name: .ReachabilityChanged, object: nil)
        
        updateNavigationItemButtons()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        if let selectedIndexPath = tableView.indexPathForSelectedRow {
            dataSource.update(
                cell: tableView.cellForRow(at: selectedIndexPath) as? PostCell,
                isAvailableOffline: dataSource.post(at: selectedIndexPath).isAvailableOffline
            )
            tableView.deselectRow(at: selectedIndexPath, animated: animated)
        }
        if dataSource.subreddits.isEmpty {
            updateFooterView()
            fetchInitial()
        } else if dataSource.rows.isEmpty {
            fetchPosts()
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
        let commentsViewController = CommentsViewController()
        commentsViewController.dataSource.post = post
        navigationController?.pushViewController(commentsViewController, animated: true)
    }
    
    func showSubredditsViewController() {
        let subredditsViewController = SubredditsViewController()
        subredditsViewController.didSelectSubreddits = { [weak self] in
            self?.dataSource.subreddits = $0
            self?.tableView.reloadData()
            self?.updateFooterView()
        }
        navigationController?.pushViewController(subredditsViewController, animated: true)
    }
    
    // MARK: - Fetching
    
    var isLoading = false {
        didSet {
            guard reachability.isOnline else { return }
            loadMoreButton.isEnabled = !isLoading
            loadMoreButton.titleEdgeInsets.left = isLoading ? -activityIndicatorCenterX.constant : 0
            activityIndicator.setAnimating(isLoading)
        }
    }
    
    @discardableResult
    func fetchInitial() -> Task<Void> {
        return fetch(dataSource.updateSelectedSubreddits())
            .continueOnSuccessWithTask(.mainThread) {
                self.tableView.reloadData()
                self.updateFooterView()
                return self.fetchPosts()
            }
    }
    
    @discardableResult
    func fetchPosts() -> Task<Void> {
        return fetch(dataSource.fetchNextPage(updating: tableView))
            .continueOnSuccessWith(.mainThread) { _ in self.updateChooseDownloadsButtonEnabled() }
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
    
    // MARK: - Posts downloading
    
    var isSavingOffline: Bool {
        return dataSource.downloader != nil
    }
    
    @discardableResult
    func startPostsDownload(for indexPaths: [IndexPath]) -> Task<Void> {
        let task = fetch(dataSource.startDownload(for: indexPaths, updating: tableView))
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
        if isEditing && reachability.isOffline {
            setEditing(false, animated: true)
        }
        dataSource.rows = []
        tableView.reloadData()
        fetchPosts()
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
            fetchPosts()
        }
    }
    
    @IBAction func showSubredditsButtonPressed(_ sender: UIButton) {
        showSubredditsViewController()
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
