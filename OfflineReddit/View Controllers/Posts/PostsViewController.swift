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
    @IBOutlet weak var downloadPostsHeaderShowing: NSLayoutConstraint!
    @IBOutlet weak var downloadPostsHeaderHiding: NSLayoutConstraint!
    
    var isLoading = false {
        didSet {
            updateChooseDownloadsButtonEnabled()
            guard reachability.isOnline else { return }
            loadMoreButton.isEnabled = !isLoading
            loadMoreButton.titleEdgeInsets.left = isLoading ? -activityIndicatorCenterX.constant : 0
            activityIndicator.setAnimating(isLoading)
        }
    }
    
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
        
        NotificationCenter.default.addObserver(self, selector: #selector(reachabilityChanged(_:)), name: .ReachabilityChanged, object: nil)
        
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
        updateStartDownloadsButtonEnabled()
        setDownloadPostsHeaderVisible(editing, animated: animated)
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
    
    // MARK: - UI Updating
    
    func updateFooterView() {
        let hideHints = !dataSource.subreddits.isEmpty
        hintLabel.isHidden = hideHints
        hintImage.isHidden = hideHints
        loadMoreButton.isHidden = !hideHints
        loadMoreButton.isEnabled = reachability.isOnline
        loadMoreButton.setTitle(reachability.isOnline ? SharedText.loadingLowercase : SharedText.offline, for: .disabled)
        activityIndicator.setAnimating(hideHints && isLoading && reachability.isOnline)
    }
    
    func updateStartDownloadsButtonEnabled() {
        downloadPostsSaveButton.isEnabled = tableView.indexPathsForSelectedRows?.isEmpty == false
    }
    
    func updateChooseDownloadsButtonEnabled() {
        chooseDownloadsButton.isEnabled = !dataSource.rows.isEmpty && !isSavingOffline && reachability.isOnline
    }
    
    func updateSelectedRow() {
        guard let selectedIndexPath = tableView.indexPathForSelectedRow else { return }
        dataSource.processPostChanges(at: selectedIndexPath)
        tableView.deselectRow(at: selectedIndexPath, animated: true)
    }
    
    func updateSelectedRowsToDownload(updateSlider: Bool) {
        let numberOfSelectedPosts = tableView.indexPathsForSelectedRows?.count ?? 0
        if updateSlider {
            downloadPostsSlider.value = Float(numberOfSelectedPosts)
        }
        downloadPostsTitleLabel.text = String.localizedStringWithFormat(SharedText.savePostsFormat, numberOfSelectedPosts)
        updateStartDownloadsButtonEnabled()
    }
    
    func setDownloadPostsHeaderVisible(_ visible: Bool, animated: Bool) {
        // Stop unsatisfiable constraints by ensuring both aren't active at once
        downloadPostsHeaderHiding.isActive = false
        downloadPostsHeaderShowing.isActive = false
        (visible ? downloadPostsHeaderShowing : downloadPostsHeaderHiding)?.isActive = true
        
        if visible {
            updateSelectedRowsToDownload(updateSlider: true)
            downloadPostsSlider.layoutIfNeeded()
        }
        
        let offsetAdjustment = visible ? max(0, downloadPostsHeader.frame.height - topLayoutGuide.length) : 0
        navigationController?.setNavigationBarHidden(visible, animated: animated)
        
        guard animated else { return }
        
        UIView.animate(withDuration: TimeInterval(UINavigationControllerHideShowBarDuration)) {
            self.view.layoutIfNeeded()
            if offsetAdjustment > 0 {
                self.tableView.contentOffset.y -= offsetAdjustment
            }
        }
    }
    
    // MARK: - Posts downloading
    
    var isSavingOffline: Bool {
        return dataSource.downloader != nil
    }
    
    @discardableResult
    func startPostsDownload(for indexPaths: [IndexPath]) -> Task<Void> {
        let task = dataSource.startDownload(for: indexPaths)
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
    
    // MARK: - UI Actions
    
    @IBAction func chooseDownloadButtonPressed(_ sender: UIBarButtonItem) {
        setEditing(true, animated: true)
    }
    
    @IBAction func startDownloadsButtonPressed(_ sender: UIButton) {
        if isEditing, let indexPaths = tableView.indexPathsForSelectedRows, !indexPaths.isEmpty {
            startPostsDownload(for: indexPaths)
        } else {
            setEditing(!isEditing, animated: true); return
        }
    }

    @IBAction func cancelDownloadsButtonPressed(_ sender: UIButton) {
        setEditing(false, animated: true)
    }
    
    @IBAction func loadMoreButtonPressed(_ sender: UIButton) {
        if !isLoading && !isSavingOffline {
            dataSource.fetchNextPageOrReloadIfOffline()
        }
    }
    
    @IBAction func showSubredditsButtonPressed(_ sender: UIButton) {
        showSubredditsViewController()
    }
    
    @IBAction func filterButtonPressed(_ sender: UIBarButtonItem) {
        showFilterPostsViewController()
    }
    
    @IBAction func downloadPostsSliderValueChanged(_ sender: UISlider) {
        var selectedIndexPaths = tableView.indexPathsForSelectedRows?.sorted() ?? []
        let desiredNumberOfSelectedPosts = Int(sender.value.rounded())
        let numberOfSelectionsToChange = desiredNumberOfSelectedPosts - selectedIndexPaths.count
        if numberOfSelectionsToChange > 0 { // Selection
            for _ in 0..<numberOfSelectionsToChange {
                let selecting = (0..<dataSource.rows.count).first { row in !selectedIndexPaths.contains { $0.row == row }}
                guard let row = selecting else { break }
                tableView.selectRow(at: IndexPath(row: row, section: 0), animated: true, scrollPosition: .none)
            }
        } else if numberOfSelectionsToChange < 0 { // Deselection
            for _ in numberOfSelectionsToChange..<0 where !selectedIndexPaths.isEmpty {
                tableView.deselectRow(at: selectedIndexPaths.removeLast(), animated: true)
            }
        }
        updateSelectedRowsToDownload(updateSlider: false)
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
