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
        dataSource.updateSelectedSubreddits().continueOnSuccessWithTask { () -> Task<[Post]> in
            self.tableView.reloadData()
            self.updateFooterView()
            return self.dataSource.fetchNextPage(updating: self.tableView)
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
            commentsViewController.dataSource.post = sender as? Post
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
        fetch(dataSource.fetchNextPage(updating: tableView))
            .continueOnSuccessWith(.mainThread) { _ in self.updateChooseDownloadsButtonEnabled() }
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
    
    var isSavingOffline: Bool {
        return dataSource.downloader != nil
    }
    
    private func startPostsDownload(for indexPaths: [IndexPath]) {
        fetch(dataSource.startDownload(for: indexPaths, updating: tableView)).continueWith { _ in
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
        if !isLoading && !isSavingOffline {
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
