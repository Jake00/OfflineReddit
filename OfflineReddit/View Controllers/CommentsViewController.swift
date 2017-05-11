//
//  CommentsViewController.swift
//  OfflineReddit
//
//  Created by Jake Bellamy on 19/03/17.
//  Copyright © 2017 Jake Bellamy. All rights reserved.
//

import UIKit
import BoltsSwift

class CommentsViewController: UIViewController, Loadable {
    
    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var headerView: UIView!
    @IBOutlet weak var subredditLabel: UILabel!
    @IBOutlet weak var authorTimeLabel: UILabel!
    @IBOutlet weak var commentsLabel: UILabel!
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var selfLabel: UILabel!
    @IBOutlet var loadingButton: UIBarButtonItem!
    @IBOutlet var expandCommentsButton: UIBarButtonItem!
    
    let dataSource = CommentsDataSource()
    lazy var provider = DataProvider.shared
    var post: Post?
    
    var isLoading = false {
        didSet {
            navigationItem.setRightBarButtonItems([isLoading ? loadingButton : expandCommentsButton], animated: true)
        }
    }
    
    // MARK: - View controller
    
    override func viewDidLoad() {
        super.viewDidLoad()
        dataSource.delegate = self
        tableView.dataSource = dataSource
        tableView.delegate = dataSource
        subredditLabel.text = post?.subredditNamePrefixed
        authorTimeLabel.text = post?.authorTimeText
        titleLabel.text = post?.title
        selfLabel.text = post?.selfText
        isLoading = false
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        if let selectedIndexPath = tableView.indexPathForSelectedRow {
            tableView.deselectRow(at: selectedIndexPath, animated: animated)
        }
        if dataSource.comments.isEmpty {
            updateDataSourceComments()
        }
        if dataSource.comments.isEmpty {
            fetchComments()
        }
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        let fittingSize = CGSize(width: tableView.frame.width, height: UILayoutFittingCompressedSize.height)
        headerView.frame.size.height = headerView.systemLayoutSizeFitting(fittingSize, withHorizontalFittingPriority: UILayoutPriorityRequired, verticalFittingPriority: UILayoutPriorityFittingSizeLevel).height
    }
    
    // MARK: -
    
    func fetchComments() {
        guard let post = post else { return }
        fetch(provider.getComments(for: post).continueOnSuccessWith(.mainThread) { _ -> Void in
            defer { _ = try? self.provider.local.save() }
            let old = self.dataSource.comments.count
            self.updateDataSourceComments()
            let new = self.dataSource.comments.count
            guard new > 0 else {
                self.tableView.reloadData()
                return
            }
            if old == 0 {
                self.tableView.beginUpdates()
                self.tableView.reloadRows(at: [IndexPath(row: 0, section: 0)], with: .fade)
            }
            self.tableView.insertRows(at: (max(1, old)..<new).map { IndexPath(row: $0, section: 0) }, with: .fade)
            if old == 0 {
                self.tableView.endUpdates()
            }
        })
    }
    
    func fetchMoreComments(using more: MoreComments) {
        guard let post = post else { return }
        fetch(provider.getMoreComments(using: [more], post: post).continueOnSuccessWith(.mainThread) { _ -> Void in
            self.dataSource.loadingCells.remove(more)
            guard let indexPath = self.dataSource.indexPath(of: more) else {
                self.updateDataSourceComments()
                self.tableView.reloadData()
                return
            }
            let start = min(indexPath.row + 1, self.dataSource.comments.endIndex - 1)
            let next = self.dataSource.comments[start]
            self.updateDataSourceComments()
            guard let end = self.dataSource.comments.index(where: { $0 == next }), end - start >= 0 else {
                self.tableView.reloadData()
                return
            }
            self.tableView.beginUpdates()
            self.tableView.reloadRows(at: [indexPath], with: .fade)
            if end - start > 0 {
                self.tableView.insertRows(at: (start..<end).map { IndexPath(row: $0, section: 0) }, with: .fade)
            }
            self.tableView.endUpdatesSafe()
            _ = try? self.provider.local.save()
        }).continueOnErrorWith(.mainThread) { _ in
            self.dataSource.loadingCells.remove(more)
            if let indexPath = self.dataSource.indexPath(of: more) {
                let cell = self.tableView.cellForRow(at: indexPath) as? MoreCell
                self.dataSource.updateMoreCell(cell, more)
            }
        }
    }
    
    func updateDataSourceComments() {
        dataSource.allComments = post?.displayComments ?? []
        let (savedCount, toExpandCount) = dataSource.allComments.reduce((0, 0) as (Int64, Int64)) {
            switch $1 {
            case .first: return ($0.0 + 1, $0.1)
            case .other(let b): return ($0.0, $0.1 + b.count)
            }
        }
        expandCommentsButton.isEnabled = toExpandCount > 0 && isOnline
        commentsLabel.text = String.localizedStringWithFormat(
            NSLocalizedString("comments_saved_format", value: "%ld comments\n%ld / %ld saved", comment: "Format for number of comments and amount saved. eg. '50 comments\n30 / 40 saved'"),
            post?.commentsCount ?? 0, savedCount, savedCount + toExpandCount)
    }
    
    @IBAction func expandCommentsButtonPressed(_ sender: UIBarButtonItem) {
        guard let post = post else { return }
        var batches = post.batchedMoreComments(for: dataSource.allComments)
        let total = batches.count
        navigationBarProgressView?.isHidden = false
        navigationBarProgressView?.setProgress(0, animated: false)
        isLoading = true
        
        func downloadNext() -> Task<Void> {
            navigationBarProgressView?.setProgress(Float(total - batches.count) / Float(total), animated: true)
            guard !batches.isEmpty else { return Task(()) }
            return provider.getMoreComments(using: batches.removeFirst(), post: post)
                .continueOnSuccessWithTask(.mainThread) { _ in downloadNext() }
        }
        
        downloadNext()
            .continueOnSuccessWithTask { Task<Void>.withDelay(1) }
            .continueWith(.mainThread) { task -> Void in
                task.error.map(self.presentErrorAlert)
                self.isLoading = false
                self.navigationBarProgressView?.isHidden = true
                self.updateDataSourceComments()
                self.tableView.reloadData()
                _ = try? self.provider.local.save()
        }
    }
}

extension CommentsViewController: CommentsDataSourceDelegate {
    
    var viewHorizontalMargins: CGFloat {
        return headerView.readableContentGuide.layoutFrame.minX * 2
    }
    
    var viewFrameWidth: CGFloat {
        return view.frame.width
    }
    
    func didSelectMoreComments(_ more: MoreComments) {
        fetchMoreComments(using: more)
    }
}
