//
//  PostsViewController.swift
//  OfflineReddit
//
//  Created by Jake Bellamy on 19/03/17.
//  Copyright © 2017 Jake Bellamy. All rights reserved.
//

import UIKit
import CoreData
import BoltsSwift

class PostsViewController: UIViewController {
    
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
    
    let context = CoreDataController.shared.viewContext
    let dataSource = PostsDataSource()
    var isSavingOffline = false
    
    var subreddits: [Subreddit] = [] {
        didSet {
            if oldValue != subreddits {
                dataSource.rows = []
                tableView.reloadData()
            }
        }
    }
    
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
        
        if subreddits.isEmpty {
            let request = Subreddit.fetchRequest(predicate: NSPredicate(format: "isSelected == YES"))
            subreddits = (try? context.fetch(request)) ?? []
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
        if subreddits.isEmpty {
            updateFooterView()
        } else if dataSource.rows.isEmpty {
            fetchPosts()
        }
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        switch segue.identifier {
        case Segues.comments?:
            let commentsViewController = segue.destination as! CommentsViewController
            commentsViewController.post = sender as! Post
        case Segues.subreddits?:
            let subredditsViewController = segue.destination as! SubredditsViewController
            subredditsViewController.didSelectSubreddits = { [weak self] in
                self?.subreddits = $0
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
            guard Reachability.shared.isOnline else { return }
            loadMoreButton.isEnabled = !isLoading
            loadMoreButton.titleEdgeInsets.left = isLoading ? -activityIndicatorCenterX.constant : 0
            activityIndicator.setAnimating(isLoading)
        }
    }
    
    func updateFooterView() {
        let hideHints = !subreddits.isEmpty
        hintLabel.isHidden = hideHints
        hintImage.isHidden = hideHints
        loadMoreButton.isHidden = !hideHints
        let isOnline = Reachability.shared.isOnline
        loadMoreButton.isEnabled = isOnline
        loadMoreButton.setTitle(isOnline ? SharedText.loadingLowercase : SharedText.offline, for: .disabled)
        activityIndicator.setAnimating(hideHints && isLoading)
    }
    
    func updateStartDownloadsButtonEnabled() {
        startDownloadsButton.isEnabled = tableView.indexPathsForSelectedRows?.isEmpty == false
    }
    
    func updateChooseDownloadsButtonEnabled() {
        chooseDownloadsButton.isEnabled = !dataSource.rows.isEmpty && !isSavingOffline && Reachability.shared.isOnline
    }
    
    func reachabilityChanged(_ notification: Notification) {
        let isOffline = Reachability.shared.isOffline
        updateFooterView()
        updateChooseDownloadsButtonEnabled()
        if isEditing && isOffline {
            setEditing(false, animated: true)
        }
        dataSource.rows = []
        self.tableView.reloadData()
        fetchPosts()
    }
    
    func fetchPosts() {
        guard Reachability.shared.isOnline else {
            let postsRequest = Post.fetchRequest(predicate: NSPredicate(format: "isAvailableOffline == YES AND subredditName IN %@", subreddits.map { $0.name }))
            postsRequest.sortDescriptors = [NSSortDescriptor(key: "order", ascending: true)]
            let posts = (try? context.fetch(postsRequest)) ?? []
            dataSource.rows = posts.map(PostCellModel.init)
            tableView.reloadData()
            return
        }
        isLoading = true
        APIClient.shared.getPosts(for: subreddits, after: dataSource.rows.last?.post)
            .continueOnSuccessWith(.mainThread) { posts -> Void in
                guard !posts.isEmpty else { return }
                let old = self.dataSource.rows.count
                self.dataSource.rows += posts.map(PostCellModel.init)
                let new = self.dataSource.rows.count
                self.tableView.beginUpdates()
                self.tableView.insertRows(at: (old..<new).map { IndexPath(row: $0, section: 0) }, with: .automatic)
                self.tableView.endUpdatesSafe()
                self.updateChooseDownloadsButtonEnabled()
            }
            .continueOnErrorWith(.mainThread, continuation: self.presentErrorAlert)
            .continueWith(.mainThread) { _ in self.isLoading = false }
    }
    
    @IBAction func chooseDownloadButtonPressed(_ sender: UIBarButtonItem) {
        setEditing(true, animated: true)
    }
    
    @IBAction func startDownloadsButtonPressed(_ sender: UIBarButtonItem) {
        guard isEditing, let indexPaths = tableView.indexPathsForSelectedRows, !indexPaths.isEmpty else {
            setEditing(!isEditing, animated: true); return
        }
        dataSource.setAllStates(to: .indented, in: tableView)
        dataSource.setState(.loading, at: indexPaths, in: tableView)
        setEditing(!isEditing, animated: true)
        isSavingOffline = true
        updateChooseDownloadsButtonEnabled()
        navigationBarProgressView?.isHidden = false
        navigationBarProgressView?.setProgress(0, animated: false)
        
        var remainingPosts = indexPaths.map(dataSource.post(at:))
        var remainingComments: [(Post, [[MoreComments]])] = []
        var total = remainingPosts.count
        var completed = -1
        
        func updateProgress() {
            completed += 1
            navigationBarProgressView?.setProgress(Float(completed) / Float(total), animated: true)
        }
        
        func downloadNextPost() -> Task<Void> {
            guard !remainingPosts.isEmpty else { return Task(()) }
            let post = remainingPosts.removeFirst()
            updateProgress()
            return APIClient.shared.getComments(for: post).continueOnSuccessWithTask(.mainThread) { _ -> Task<Void> in
                post.isAvailableOffline = true
                let comments = post.batchedMoreComments(maximum: 3)
                total += comments.count
                remainingComments.append((post, comments))
                return downloadNextPost()
            }
        }
        
        func downloadNextPostsComments() -> Task<Void> {
            guard !remainingComments.isEmpty else {
                completed = total - 1
                updateProgress()
                return Task(())
            }
            var (post, comments) = remainingComments.removeFirst()
            
            func downloadNextCommentBatch() -> Task<Void> {
                guard !comments.isEmpty else { return Task(()) }
                updateProgress()
                return APIClient.shared.getMoreComments(using: comments.removeFirst(), post: post)
                    .continueOnSuccessWithTask(.mainThread) { _ in downloadNextCommentBatch() }
            }
            
            return downloadNextCommentBatch().continueOnSuccessWithTask(.mainThread) { _ -> Task<Void> in
                self.dataSource.setState(.checked, for: post, in: self.tableView)
                return downloadNextPostsComments()
            }
        }
        
        downloadNextPost()
            .continueOnSuccessWithTask(.mainThread, continuation: downloadNextPostsComments)
            .continueOnSuccessWithTask { Task<Void>.withDelay(1) }
            .continueOnSuccessWith(.mainThread) {
                for indexPath in indexPaths {
                    (self.tableView.cellForRow(at: indexPath) as? PostCell)?.offlineImageView.isHidden = false
                }
            }.continueWith(.mainThread) { task -> Void in
                task.error.map(self.presentErrorAlert)
                self.isSavingOffline = false
                self.updateChooseDownloadsButtonEnabled()
                self.navigationBarProgressView?.isHidden = true
                self.dataSource.setAllStates(to: .normal, in: self.tableView)
                UIView.animate(withDuration: 0.4) {
                    self.tableView.layoutIfNeeded()
                    self.tableView.beginUpdates()
                    self.tableView.endUpdates()
                }
                _ = try? CoreDataController.shared.viewContext.save()
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
