//
//  PostsViewController.swift
//  OfflineReddit
//
//  Created by Jake Bellamy on 19/03/17.
//  Copyright © 2017 Jake Bellamy. All rights reserved.
//

import UIKit
import BoltsSwift

class PostsViewController: UIViewController {
    
    @IBOutlet weak var tableView: UITableView!
    @IBOutlet var progressView: UIProgressView!
    
    var downloadBarButtonItem: UIBarButtonItem?
    var states: [IndexPath: PostCell.State] = [:]
    var isSavingOffline = false
    var posts: [Post] = []
    
    var isLoading = false {
        didSet {
            (tableView.cellForRow(at: IndexPath(row: posts.count, section: 0)) as? MoreCell).map(updateMoreCell)
        }
    }
    
    struct Segues {
        static let comments = "Comments"
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.rowHeight = UITableViewAutomaticDimension
        tableView.estimatedRowHeight = 50
        tableView.register(MoreCell.self, forCellReuseIdentifier: "More")
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        if let selectedIndexPath = tableView.indexPathForSelectedRow {
            tableView.deselectRow(at: selectedIndexPath, animated: animated)
        }
        if posts.isEmpty {
            fetchPosts()
        }
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        switch segue.identifier {
        case Segues.comments?:
            let commentsViewController = segue.destination as! CommentsViewController
            commentsViewController.post = sender as! Post
        default: ()
        }
    }
    
    override func setEditing(_ editing: Bool, animated: Bool) {
        let wasEditing = isEditing
        super.setEditing(editing, animated: animated)
        tableView.setEditing(isEditing, animated: true)
        tableView.beginUpdates()
        if wasEditing && !editing {
            tableView.insertRows(at: [IndexPath(row: posts.count, section: 0)], with: .fade)
        } else if !wasEditing && editing {
            tableView.deleteRows(at: [IndexPath(row: posts.count, section: 0)], with: .fade)
        }
        tableView.endUpdates()
        var items: [UIBarButtonItem] = [
            UIBarButtonItem(image: editing ? #imageLiteral(resourceName: "tick") : #imageLiteral(resourceName: "download"), style: .plain, target: self, action: #selector(downloadButtonPressed(_:)))
        ]
        downloadBarButtonItem = items.first
        if editing {
            downloadBarButtonItem?.isEnabled = false
            items.insert(UIBarButtonItem(image: #imageLiteral(resourceName: "cross"), style: .plain, target: self, action: #selector(cancelEditingButtonPressed(_:))), at: 0)
        }
        navigationItem.setRightBarButtonItems(items, animated: animated)
    }
    
    func updateMoreCell(_ cell: MoreCell) {
        (isLoading ? cell.activityIndicator.startAnimating : cell.activityIndicator.stopAnimating)()
        cell.titleLabel.isHidden = isLoading
    }
    
    func fetchPosts() {
        isLoading = true
        APIClient.shared.getPosts(for: ["AskReddit"], after: posts.last).continueWith(.mainThread) { task -> Void in
            if let posts = task.result, !posts.isEmpty {
                let old = self.posts.count
                self.posts += posts
                let new = self.posts.count
                self.tableView.insertRows(at: (old..<new).map { IndexPath(row: $0, section: 0) }, with: .automatic)
            } else if let error = task.error {
                self.presentErrorAlert(error: error)
            }
            self.isLoading = false
        }
    }
    
    @IBAction func downloadButtonPressed(_ sender: UIBarButtonItem) {
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
        downloadBarButtonItem?.isEnabled = false
        self.isSavingOffline = true
        
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
                self.isSavingOffline = false
                self.progressView.removeFromSuperview()
                self.downloadBarButtonItem?.isEnabled = true
                self.states.removeAll()
                for cell in self.tableView.visibleCells {
                    (cell as? PostCell)?.state = .normal
                }
                self.tableView.beginUpdates()
                self.tableView.endUpdates()
                _ = try? CoreDataController.shared.viewContext.save()
        }
    }

    func cancelEditingButtonPressed(_ sender: UIBarButtonItem) {
        setEditing(false, animated: true)
    }
}

extension PostsViewController: UITableViewDataSource {
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return posts.count + (isEditing ? 0 : 1)
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard indexPath.row < posts.count else {
            let cell = tableView.dequeueReusableCell(withIdentifier: "More", for: indexPath) as! MoreCell
            cell.titleLabel.text = "\n" + SharedText.showMore + "\n"
            updateMoreCell(cell)
            cell.setNeedsLayout()
            cell.layoutIfNeeded()
            return cell
        }
        let cell = tableView.dequeueReusableCell(withIdentifier: "Post", for: indexPath) as! PostCell
        let post = posts[indexPath.row]
        cell.topLabel.text = post.authorTimeText
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
            downloadBarButtonItem?.isEnabled = tableView.indexPathsForSelectedRows?.isEmpty == false
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
            downloadBarButtonItem?.isEnabled = tableView.indexPathsForSelectedRows?.isEmpty == false
        }
    }
}

class PostCell: UITableViewCell {
    
    @IBOutlet weak var topLabel: UILabel!
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var bottomLabel: UILabel!
    @IBOutlet weak var checkedImageView: UIImageView!
    @IBOutlet weak var activityIndicator: UIActivityIndicatorView!
    @IBOutlet weak var container: UIView!
    @IBOutlet weak var containerLeading: NSLayoutConstraint!
    @IBOutlet weak var offlineImageView: UIImageView!
    
    enum State {
        case normal
        case indented
        case loading
        case checked
    }
    
    var state: State = .normal {
        didSet {
            containerLeading.constant = state == .normal ? 0 : 38
            (state == .loading ? activityIndicator.startAnimating : activityIndicator.stopAnimating)()
            checkedImageView.isHidden = state != .checked
        }
    }
    
    override init(style: UITableViewCellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setup()
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        setup()
    }
    
    private func setup() {
        let selectedBackgroundView = UIView()
        selectedBackgroundView.backgroundColor = .selectedGray
        self.selectedBackgroundView = selectedBackgroundView
    }
    
}
