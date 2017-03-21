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
    var states: [Post: PostCell.State] = [:]
    var isSavingOffline = false
    var posts: [Post] = []
    var subreddits: [Subreddit] = [] {
        didSet {
            if oldValue != subreddits {
                posts = []
                tableView.reloadData()
            }
        }
    }
    
    var isLoading = false {
        didSet {
            guard Reachability.shared.isOnline else { return }
            loadMoreButton.isEnabled = !isLoading
            loadMoreButton.titleEdgeInsets.left = isLoading ? -activityIndicatorCenterX.constant : 0
            (isLoading ? activityIndicator.startAnimating : activityIndicator.stopAnimating)()
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
        (hideHints && isLoading ? activityIndicator.startAnimating : activityIndicator.stopAnimating)()
    }
    
    struct Segues {
        static let comments = "Comments"
        static let subreddits = "Subreddits"
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.rowHeight = UITableViewAutomaticDimension
        tableView.estimatedRowHeight = 50
        
        if subreddits.isEmpty {
            let request = Subreddit.fetchRequest(predicate: NSPredicate(format: "isSelected == YES"))
            subreddits = (try? context.fetch(request)) ?? []
        }
        
        NotificationCenter.default.addObserver(self, selector: #selector(reachabilityChanged(_:)), name: .ReachabilityChanged, object: nil)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        if let selectedIndexPath = tableView.indexPathForSelectedRow {
            (tableView.cellForRow(at: selectedIndexPath) as? PostCell)?.offlineImageView.isHidden = !posts[selectedIndexPath.row].isAvailableOffline
            tableView.deselectRow(at: selectedIndexPath, animated: animated)
        }
        if subreddits.isEmpty {
            updateFooterView()
        } else if posts.isEmpty {
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
    
    func updateStartDownloadsButtonEnabled() {
        startDownloadsButton.isEnabled = tableView.indexPathsForSelectedRows?.isEmpty == false
    }
    
    func updateChooseDownloadsButtonEnabled() {
        chooseDownloadsButton.isEnabled = !posts.isEmpty && !isSavingOffline && Reachability.shared.isOnline
    }
    
    func reachabilityChanged(_ notification: Notification) {
        print("Reachability changed, isOnline: \(Reachability.shared.isOnline)")
        let isOffline = Reachability.shared.isOffline
        updateFooterView()
        updateChooseDownloadsButtonEnabled()
        if isEditing && isOffline {
            setEditing(false, animated: true)
        }
        posts = []
        self.tableView.reloadData()
        fetchPosts()
    }
    
    func fetchPosts() {
        guard Reachability.shared.isOnline else {
            let postsRequest = Post.fetchRequest(predicate: NSPredicate(format: "isAvailableOffline == YES AND subredditName IN %@", subreddits.map { $0.name }))
            postsRequest.sortDescriptors = [NSSortDescriptor(key: "order", ascending: true)]
            posts = (try? context.fetch(postsRequest)) ?? []
            tableView.reloadData()
            return
        }
        isLoading = true
        APIClient.shared.getPosts(for: subreddits, after: posts.last).continueWith(.mainThread) { task -> Void in
            if let posts = task.result, !posts.isEmpty {
                let old = self.posts.count
                self.posts += posts
                let new = self.posts.count
                self.tableView.beginUpdates()
                self.tableView.insertRows(at: (old..<new).map { IndexPath(row: $0, section: 0) }, with: .automatic)
                self.tableView.endUpdatesSafe()
                self.updateChooseDownloadsButtonEnabled()
            } else if let error = task.error {
                self.presentErrorAlert(error: error)
            }
            self.isLoading = false
        }
    }
    
    func cell(for post: Post) -> PostCell? {
        return posts.index(of: post)
            .map { IndexPath(row: $0, section: 0) }
            .flatMap { tableView.cellForRow(at: $0) as? PostCell }
    }
    
    @IBAction func chooseDownloadButtonPressed(_ sender: UIBarButtonItem) {
        setEditing(true, animated: true)
    }
    
    @IBAction func startDownloadsButtonPressed(_ sender: UIBarButtonItem) {
        guard isEditing, let indexPaths = tableView.indexPathsForSelectedRows, !indexPaths.isEmpty else {
            setEditing(!isEditing, animated: true); return
        }
        for cell in tableView.visibleCells {
            (cell as? PostCell)?.state = .indented
        }
        for indexPath in indexPaths {
            states[posts[indexPath.row]] = .loading
            let cell = tableView.cellForRow(at: indexPath) as? PostCell
            cell?.state = .loading
            cell?.prepareForLoadingTransition()
        }
        
        setEditing(!isEditing, animated: true)
        isSavingOffline = true
        updateChooseDownloadsButtonEnabled()
        navigationBarProgressView?.isHidden = false
        navigationBarProgressView?.setProgress(0, animated: false)
        
        var remainingPosts = indexPaths.map { posts[$0.row] }
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
                self.states[post] = .checked
                self.cell(for: post)?.state = .checked
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
                self.states.removeAll()
                for cell in self.tableView.visibleCells {
                    (cell as? PostCell)?.state = .normal
                }
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

extension PostsViewController: UITableViewDataSource {
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return posts.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "Post", for: indexPath) as! PostCell
        let post = posts[indexPath.row]
        cell.topLabel.text = post.subredditAuthorTimeText
        cell.titleLabel.text = post.title
        cell.bottomLabel.text = post.scoreCommentsText
        cell.state = states[post] ?? (isSavingOffline ? .indented : .normal)
        cell.offlineImageView.isHidden = !post.isAvailableOffline
        cell.setNeedsLayout()
        cell.layoutIfNeeded()
        return cell
    }
}

extension PostsViewController: UITableViewDelegate {
    
    func tableView(_ tableView: UITableView, shouldHighlightRowAt indexPath: IndexPath) -> Bool {
        return !isSavingOffline && (indexPath.row != posts.count || !isLoading)
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if isEditing {
            updateStartDownloadsButtonEnabled()
        } else {
            performSegue(withIdentifier: Segues.comments, sender: posts[indexPath.row])
        }
    }
    
    func tableView(_ tableView: UITableView, didDeselectRowAt indexPath: IndexPath) {
        if isEditing {
            updateStartDownloadsButtonEnabled()
        }
    }
}
