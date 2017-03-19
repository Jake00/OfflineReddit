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
        navigationItem.setLeftBarButton(editing ? UIBarButtonItem(image: #imageLiteral(resourceName: "cross"), style: .plain, target: self, action: #selector(cancelEditingButtonPressed(_:))) : nil, animated: animated)
        navigationItem.setRightBarButton(UIBarButtonItem(image: editing ? #imageLiteral(resourceName: "tick") : #imageLiteral(resourceName: "download"), style: .plain, target: self, action: #selector(downloadButtonPressed(_:))), animated: animated)
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
        if isEditing, let indexPaths = tableView.indexPathsForSelectedRows, !indexPaths.isEmpty {
            if let bar = navigationController?.navigationBar {
                bar.addSubview(progressView)
                progressView.frame = CGRect(x: 0, y: bar.frame.height - progressView.frame.height, width: bar.frame.width, height: progressView.frame.height)
                progressView.setProgress(0, animated: false)
                progressView.layoutIfNeeded()
            }
            let posts = indexPaths.map { self.posts[$0.row] }
            var remaining = posts
            func downloadNext() -> Task<Void> {
                progressView.setProgress(Float(posts.count - remaining.count) / Float(posts.count), animated: true)
                guard !remaining.isEmpty else { return Task(()) }
                return APIClient.shared.getComments(for: remaining.removeFirst())
                    .continueOnSuccessWithTask(.mainThread) { _ in downloadNext() }
            }
            downloadNext()
                .continueOnSuccessWithTask { Task<Void>.withDelay(1) }
                .continueOnSuccessWith(.mainThread) {
                    self.progressView.removeFromSuperview()
            }
            
        }
        setEditing(!isEditing, animated: true)
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
        cell.setNeedsLayout()
        cell.layoutIfNeeded()
        return cell
    }
}

extension PostsViewController: UITableViewDelegate {
    
    func tableView(_ tableView: UITableView, shouldHighlightRowAt indexPath: IndexPath) -> Bool {
        return indexPath.row != posts.count || !isLoading
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        guard !isEditing else { return }
        if indexPath.row == posts.count {
            if !isLoading {
                fetchPosts()
            }
            tableView.deselectRow(at: indexPath, animated: true)
        } else {
            performSegue(withIdentifier: Segues.comments, sender: posts[indexPath.row])
        }
    }
}

class PostCell: UITableViewCell {
    @IBOutlet weak var topLabel: UILabel!
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var bottomLabel: UILabel!
}
