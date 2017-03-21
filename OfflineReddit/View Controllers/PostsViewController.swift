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
    @IBOutlet var progressView: UIProgressView!
    @IBOutlet var subredditsButton: UIBarButtonItem!
    @IBOutlet var chooseDownloadsButton: UIBarButtonItem!
    @IBOutlet var startDownloadsButton: UIBarButtonItem!
    @IBOutlet var cancelDownloadsButton: UIBarButtonItem!
    
    let context = CoreDataController.shared.viewContext
    var states: [IndexPath: PostCell.State] = [:]
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
            loadMoreButton.isEnabled = !isLoading
            loadMoreButton.titleEdgeInsets.left = isLoading ? -activityIndicatorCenterX.constant : 0
            (isLoading ? activityIndicator.startAnimating : activityIndicator.stopAnimating)()
        }
    }
    
    func updateIsHintHidden() {
        let show = !subreddits.isEmpty
        hintLabel.isHidden = show
        hintImage.isHidden = show
        loadMoreButton.isHidden = !show
        (show && isLoading ? activityIndicator.startAnimating : activityIndicator.stopAnimating)()
    }
    
    struct Segues {
        static let comments = "Comments"
        static let subreddits = "Subreddits"
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.rowHeight = UITableViewAutomaticDimension
        tableView.estimatedRowHeight = 50
        
        if subreddits.isEmpty {
            let request = Subreddit.fetchRequest(predicate: NSPredicate(format: "isSelected == YES"))
            subreddits = (try? context.fetch(request)) ?? []
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        if let selectedIndexPath = tableView.indexPathForSelectedRow {
            tableView.deselectRow(at: selectedIndexPath, animated: animated)
        }
        if subreddits.isEmpty {
            updateIsHintHidden()
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
                self?.updateIsHintHidden()
            }
        default: ()
        }
    }
    
    override func setEditing(_ editing: Bool, animated: Bool) {
        super.setEditing(editing, animated: animated)
        tableView.setEditing(isEditing, animated: true)
        updateStartDownloadsButtonEnabled()
        navigationItem.setRightBarButtonItems(editing ? [cancelDownloadsButton, startDownloadsButton] : [subredditsButton], animated: animated)
        navigationItem.setLeftBarButtonItems(editing ? nil : [chooseDownloadsButton], animated: animated)
    }
    
    func updateStartDownloadsButtonEnabled() {
        startDownloadsButton.isEnabled = tableView.indexPathsForSelectedRows?.isEmpty == false
    }
    
    func updateChooseDownloadsButtonEnabled() {
        chooseDownloadsButton.isEnabled = !posts.isEmpty
    }
    
    func fetchPosts() {
        isLoading = true
        APIClient.shared.getPosts(for: subreddits, after: posts.last).continueWith(.mainThread) { task -> Void in
            if let posts = task.result, !posts.isEmpty {
                let old = self.posts.count
                self.posts += posts
                let new = self.posts.count
                self.tableView.insertRows(at: (old..<new).map { IndexPath(row: $0, section: 0) }, with: .automatic)
                self.updateChooseDownloadsButtonEnabled()
            } else if let error = task.error {
                self.presentErrorAlert(error: error)
            }
            self.isLoading = false
        }
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
            states[indexPath] = .loading
            (tableView.cellForRow(at: indexPath) as? PostCell)?.state = .loading
        }
        
        setEditing(!isEditing, animated: true)
        chooseDownloadsButton.isEnabled = false
        isSavingOffline = true
        
        if let bar = navigationController?.navigationBar {
            bar.addSubview(progressView)
            progressView.frame = CGRect(x: 0, y: bar.frame.height - progressView.frame.height, width: bar.frame.width, height: progressView.frame.height)
            progressView.setProgress(0, animated: false)
            progressView.layoutIfNeeded()
        }
        let posts = indexPaths.map { ($0, self.posts[$0.row]) }
        var remaining = posts
        
        func downloadNext() -> Task<Void> {
            progressView.setProgress(Float(posts.count - remaining.count) / Float(posts.count), animated: true)
            guard !remaining.isEmpty else { return Task(()) }
            let (indexPath, post) = remaining.removeFirst()
            return APIClient.shared.getComments(for: post).continueOnSuccessWithTask(.mainThread) { _ -> Task<Void> in
                post.isAvailableOffline = true
                self.states[indexPath] = .checked
                (self.tableView.cellForRow(at: indexPath) as? PostCell)?.state = .checked
                return downloadNext()
            }
        }
        downloadNext()
            .continueOnSuccessWithTask { Task<Void>.withDelay(1) }
            .continueOnSuccessWith(.mainThread) {
                for indexPath in indexPaths {
                    (self.tableView.cellForRow(at: indexPath) as? PostCell)?.offlineImageView.isHidden = false
                }
            }.continueWith(.mainThread) { task -> Void in
                task.error.map(self.presentErrorAlert)
                self.chooseDownloadsButton.isEnabled = true
                self.isSavingOffline = false
                self.progressView.removeFromSuperview()
                self.states.removeAll()
                for cell in self.tableView.visibleCells {
                    (cell as? PostCell)?.state = .normal
                }
                self.tableView.beginUpdates()
                self.tableView.endUpdates()
                _ = try? CoreDataController.shared.viewContext.save()
        }

    }

    @IBAction func cancelDownloadsButtonPressed(_ sender: UIBarButtonItem) {
        setEditing(false, animated: true)
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
        cell.state = states[indexPath] ?? (isSavingOffline ? .indented : .normal)
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
        guard !isEditing else {
            updateStartDownloadsButtonEnabled()
            return
        }
        if indexPath.row == posts.count {
            if !isLoading {
                fetchPosts()
            }
            tableView.deselectRow(at: indexPath, animated: true)
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
