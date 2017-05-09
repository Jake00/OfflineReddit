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
    @IBOutlet weak var footerView: UIView!
    @IBOutlet weak var loadMoreButton: UIButton!
    @IBOutlet weak var activityIndicator: UIActivityIndicatorView!
    @IBOutlet weak var activityIndicatorCenterX: NSLayoutConstraint!
    @IBOutlet weak var hintLabel: UILabel!
    @IBOutlet weak var hintImage: UIImageView!
    @IBOutlet var subredditsButton: UIBarButtonItem!
    @IBOutlet var chooseDownloadsButton: UIBarButtonItem!
    @IBOutlet var startDownloadsButton: UIBarButtonItem!
    @IBOutlet var cancelDownloadsButton: UIBarButtonItem!
    
    let dataSource = PostsDataSource()
    let provider = DataProvider()
    private(set) var isSavingOffline = false
    
    struct Segues {
        static let comments = "Comments"
        static let subreddits = "Subreddits"
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
        
        if dataSource.subreddits.isEmpty {
            provider.getSelectedSubreddits().continueOnSuccessWith {
                self.dataSource.subreddits = $0
                self.tableView.reloadData()
            }
        }
        
        NotificationCenter.default.addObserver(self, selector: #selector(reachabilityChanged(_:)), name: .ReachabilityChanged, object: nil)
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
        } else if dataSource.rows.isEmpty {
            fetchPosts()
        }
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        switch segue.identifier {
        case Segues.comments?:
            let commentsViewController = segue.destination as! CommentsViewController
            commentsViewController.post = sender as? Post
            commentsViewController.provider.remote = provider.remote
        case Segues.subreddits?:
            let subredditsViewController = segue.destination as! SubredditsViewController
            subredditsViewController.didSelectSubreddits = { [weak self] in
                self?.dataSource.subreddits = $0
                self?.tableView.reloadData()
                self?.updateFooterView()
            }
        default: ()
        }
    }
    
    override func setEditing(_ editing: Bool, animated: Bool) {
        super.setEditing(editing, animated: animated)
        tableView.setEditing(isEditing, animated: true)
        tableView.beginUpdates()
        tableView.endUpdates()
        updateStartDownloadsButtonEnabled()
        navigationItem.setRightBarButtonItems(editing ? [cancelDownloadsButton, startDownloadsButton] : [subredditsButton], animated: animated)
        navigationItem.setLeftBarButtonItems(editing ? nil : [chooseDownloadsButton], animated: animated)
    }
    
    // MARK: - Updating
    
    var isLoading = false {
        didSet {
            guard isOnline else { return }
            loadMoreButton.isEnabled = !isLoading
            loadMoreButton.titleEdgeInsets.left = isLoading ? -activityIndicatorCenterX.constant : 0
            activityIndicator.setAnimating(isLoading)
        }
    }
    
    func fetchPosts() {
        fetch(provider.getPosts(for: dataSource.subreddits, after: dataSource.rows.last?.post)
            .continueOnSuccessWith(.mainThread, continuation: updateWithNewPosts))
    }
    
    private func updateWithNewPosts(_ posts: [Post], context: DataProvider.UpdateContext) {
        let rows = posts.map(PostCellModel.init)
        switch context {
        case .replace:
            self.dataSource.rows = rows
            self.tableView.reloadData()
        case .append:
            guard !rows.isEmpty else { return }
            let old = self.dataSource.rows.count
            self.dataSource.rows += rows
            let new = self.dataSource.rows.count
            let indexPaths = (old..<new).map { IndexPath(row: $0, section: 0) }
            self.tableView.insertRowsSafe(at: indexPaths, with: .fade)
        }
        self.updateChooseDownloadsButtonEnabled()
    }
    
    func updateFooterView() {
        let hideHints = !dataSource.subreddits.isEmpty
        hintLabel.isHidden = hideHints
        hintImage.isHidden = hideHints
        loadMoreButton.isHidden = !hideHints
        loadMoreButton.isEnabled = isOnline
        loadMoreButton.setTitle(isOnline ? SharedText.loadingLowercase : SharedText.offline, for: .disabled)
        activityIndicator.setAnimating(hideHints && isLoading)
    }
    
    func updateStartDownloadsButtonEnabled() {
        startDownloadsButton.isEnabled = tableView.indexPathsForSelectedRows?.isEmpty == false
    }
    
    func updateChooseDownloadsButtonEnabled() {
        chooseDownloadsButton.isEnabled = !dataSource.rows.isEmpty && !isSavingOffline && isOnline
    }
    
    // MARK: - Posts downloading
    
    private func startPostsDownload(for indexPaths: [IndexPath]) {
        let downloader = PostsDownloader(posts: indexPaths.map(dataSource.post(at:)), provider: provider.remote)
        downloader.completionForPost = { post in
            self.dataSource.setState(.checked, for: post, in: self.tableView)
        }
        downloader.completionBlock = {
            DispatchQueue.main.async {
                self.postsDownloadDidComplete(downloader, at: indexPaths)
            }
        }
        isSavingOffline = true
        dataSource.setAllStates(to: .indented, in: tableView)
        dataSource.setState(.loading, at: indexPaths, in: tableView)
        setEditing(!isEditing, animated: true)
        updateChooseDownloadsButtonEnabled()
        navigationBarProgressView?.isHidden = false
        navigationBarProgressView?.setProgress(0, animated: false)
        navigationBarProgressView?.observedProgress = downloader.progress
        
        downloader.start()
    }
    
    private func postsDownloadDidComplete(_ downloader: PostsDownloader, at indexPaths: [IndexPath]) {
        isSavingOffline = false
        downloader.error.map(self.presentErrorAlert)
        navigationBarProgressView?.observedProgress = nil
        navigationBarProgressView?.setProgress(1, animated: true)
        dataSource.updateIsAvailableOffline(at: indexPaths, in: tableView)
        dataSource.setAllStates(to: .normal, in: tableView)
        updateChooseDownloadsButtonEnabled()
        navigationBarProgressView?.isHidden = true
        UIView.animate(withDuration: 0.4) {
            self.tableView.layoutIfNeeded()
            self.tableView.beginUpdates()
            self.tableView.endUpdates()
        }
        _ = try? provider.local.save()
    }
    
    // MARK: - Reachablity
    
    func reachabilityChanged(_ notification: Notification) {
        updateFooterView()
        updateChooseDownloadsButtonEnabled()
        if isEditing && isOffline {
            setEditing(false, animated: true)
        }
        dataSource.rows = []
        self.tableView.reloadData()
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
        if !isLoading {
            fetchPosts()
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
            updateStartDownloadsButtonEnabled()
        } else {
            performSegue(withIdentifier: Segues.comments, sender: dataSource.post(at: indexPath))
        }
    }
    
    func tableView(_ tableView: UITableView, didDeselectRowAt indexPath: IndexPath) {
        if isEditing {
            updateStartDownloadsButtonEnabled()
        }
    }
}
