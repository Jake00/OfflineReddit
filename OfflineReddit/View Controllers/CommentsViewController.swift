//
//  CommentsViewController.swift
//  OfflineReddit
//
//  Created by Jake Bellamy on 19/03/17.
//  Copyright © 2017 Jake Bellamy. All rights reserved.
//

import UIKit
import BoltsSwift

class CommentsViewController: UIViewController {
    
    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var headerView: UIView!
    @IBOutlet weak var subredditLabel: UILabel!
    @IBOutlet weak var authorTimeLabel: UILabel!
    @IBOutlet weak var commentsLabel: UILabel!
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var selfLabel: UILabel!
    @IBOutlet var loadingButton: UIBarButtonItem!
    @IBOutlet var expandCommentsButton: UIBarButtonItem!
    
    let context = CoreDataController.shared.viewContext
    var post: Post!
    var comments: [Either<Comment, MoreComments>] = []
    var allComments: [Either<Comment, MoreComments>] = []
    var loading: Set<MoreComments> = []
    var isLoading = false {
        didSet {
            navigationItem.setRightBarButtonItems([isLoading ? loadingButton : expandCommentsButton], animated: true)
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        subredditLabel.text = post.subredditNamePrefixed
        authorTimeLabel.text = post.authorTimeText
        titleLabel.text = post.title
        selfLabel.text = post.selfText
        isLoading = false
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        if let selectedIndexPath = tableView.indexPathForSelectedRow {
            tableView.deselectRow(at: selectedIndexPath, animated: animated)
        }
        if comments.isEmpty {
            updateComments()
        }
        if comments.isEmpty {
            fetchComments()
        }
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        let fittingSize = CGSize(width: tableView.frame.width, height: UILayoutFittingCompressedSize.height)
        headerView.frame.size.height = headerView.systemLayoutSizeFitting(fittingSize, withHorizontalFittingPriority: UILayoutPriorityRequired, verticalFittingPriority: UILayoutPriorityFittingSizeLevel).height
    }
    
    func indexPath(of more: MoreComments) -> IndexPath? {
        let v = Either<Comment, MoreComments>.other(more)
        return comments.index(where: { $0 == v })
            .map { IndexPath(row: $0, section: 0) }
    }
    
    func fetchComments() {
        isLoading = true
        APIClient.shared.getComments(for: post).continueWith(.mainThread) { task -> Void in
            self.isLoading = false
            if let error = task.error {
                self.presentErrorAlert(error: error)
                return
            }
            self.post.isAvailableOffline = true
            let old = self.comments.count
            self.updateComments()
            let new = self.comments.count
            guard new > 0 else {
                self.tableView.reloadData()
                _ = try? self.context.save()
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
            _ = try? self.context.save()
        }
    }
    
    func fetchMoreComments(using more: MoreComments) {
        isLoading = true
        APIClient.shared.getMoreComments(using: [more], post: post).continueOnSuccessWith(.mainThread) { _ -> Void in
            self.isLoading = false
            self.loading.remove(more)
            guard let indexPath = self.indexPath(of: more) else {
                self.updateComments()
                self.tableView.reloadData()
                return
            }
            let start = min(indexPath.row + 1, self.comments.endIndex - 1)
            let next = self.comments[start]
            self.updateComments()
            guard let end = self.comments.index(where: { $0 == next }), end - start >= 0 else {
                self.tableView.reloadData()
                return
            }
            self.tableView.beginUpdates()
            self.tableView.reloadRows(at: [indexPath], with: .fade)
            if end - start > 0 {
                self.tableView.insertRows(at: (start..<end).map { IndexPath(row: $0, section: 0) }, with: .fade)
            }
            self.tableView.endUpdatesSafe()
            _ = try? self.context.save()
            }.continueOnErrorWith(.mainThread) {
                self.presentErrorAlert(error: $0)
                self.loading.remove(more)
                if let indexPath = self.indexPath(of: more) {
                    self.updateMoreCell(at: indexPath, more)
                }
        }
    }
    
    func updateComments() {
        allComments = post.displayComments
        var condensedComment: Comment?
        comments = allComments.filter {
            switch $0 {
            case .other: return true
            case .first(let next):
                if let comment = condensedComment {
                    let isSibling = next.depth > comment.depth
                    if !isSibling {
                        condensedComment = nil
                    }
                    return !isSibling
                } else if !next.isExpanded {
                    condensedComment = next
                }
                return true
            }
        }
        let (savedCount, toExpandCount) = allComments.reduce((0, 0) as (Int64, Int64)) {
            switch $1 {
            case .first: return ($0.0 + 1, $0.1)
            case .other(let b): return ($0.0, $0.1 + b.count)
            }
        }
        expandCommentsButton.isEnabled = toExpandCount > 0 && Reachability.shared.isOnline
        commentsLabel.text = String.localizedStringWithFormat(
            NSLocalizedString("comments_saved_format", value: "%ld comments\n%ld / %ld saved", comment: "Format for number of comments and amount saved. eg. '50 comments\n30 / 40 saved'"),
            post.commentsCount, savedCount, savedCount + toExpandCount)
    }
    
    func updateMoreCell(at indexPath: IndexPath, _ more: MoreComments? = nil, cell: MoreCell? = nil, forceLoad: Bool = false) {
        guard let cell = cell ?? tableView.cellForRow(at: indexPath) as? MoreCell else { return }
        let isLoading = (more.map(loading.contains) ?? false) || forceLoad
        cell.titleLabel.text = isLoading
            ? SharedText.loadingCaps
            : String.localizedStringWithFormat(SharedText.repliesFormat, more?.count ?? 0)
        (isLoading ? cell.activityIndicator.startAnimating : cell.activityIndicator.stopAnimating)()
    }
    
    func flipCellExpanded(at indexPath: IndexPath, comment: Comment) {
        comment.isExpanded = !comment.isExpanded
        let cell = tableView.cellForRow(at: indexPath) as? CommentCell
        cell?.isExpanded = comment.isExpanded
        cell?.isExpanding = comment.isExpanded
        
        tableView.beginUpdates()
        var delta = 0
        let indexPaths: () -> [IndexPath] = {
            (indexPath.row + 1..<indexPath.row + 1 + delta).map { IndexPath(row: $0, section: 0) }
        }
        if comment.isExpanded {
            var row = indexPath.row + 1
            if var index = allComments.index(where: { $0.first == comment }) {
                while index + 1 < allComments.endIndex,
                    comment.depth < allComments[index + 1].depth,
                    allComments[index].isExpanded {
                        comments.insert(allComments[index + 1], at: row)
                        row += 1
                        index += 1
                        delta += 1
                }
                if delta > 0 {
                    tableView.insertRows(at: indexPaths(), with: .fade)
                }
            }
        } else {
            while indexPath.row + 1 < comments.endIndex,
                comment.depth < comments[indexPath.row + 1].depth {
                    comments.remove(at: indexPath.row + 1)
                    delta += 1
            }
            if delta > 0 {
                tableView.deleteRows(at: indexPaths(), with: .fade)
            }
        }
        tableView.endUpdates()
        cell?.isExpanding = false
        tableView.scrollToRow(at: indexPath, at: .none, animated: true)
    }
    
    @IBAction func expandCommentsButtonPressed(_ sender: UIBarButtonItem) {
        var batches = post.batchedMoreComments(for: allComments)
        let total = batches.count
        navigationBarProgressView?.isHidden = false
        navigationBarProgressView?.setProgress(0, animated: false)
        isLoading = true
        
        func downloadNext() -> Task<Void> {
            navigationBarProgressView?.setProgress(Float(total - batches.count) / Float(total), animated: true)
            guard !batches.isEmpty else { return Task(()) }
            return APIClient.shared.getMoreComments(using: batches.removeFirst(), post: post)
                .continueOnSuccessWithTask(.mainThread) { _ in downloadNext() }
        }
        
        downloadNext()
            .continueOnSuccessWithTask { Task<Void>.withDelay(1) }
            .continueWith(.mainThread) { task -> Void in
                task.error.map(self.presentErrorAlert)
                self.isLoading = false
                self.navigationBarProgressView?.isHidden = true
                self.updateComments()
                self.tableView.reloadData()
                _ = try? self.context.save()
        }
    }
}

extension CommentsViewController: UITableViewDataSource {
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return max(1, comments.count)
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard !comments.isEmpty else {
            let cell = tableView.dequeueReusableCell(withIdentifier: "More", for: indexPath) as! MoreCell
            updateMoreCell(at: indexPath, cell: cell, forceLoad: true)
            cell.indentationLevel = 0
            return cell
        }
        switch comments[indexPath.row] {
        case .first(let comment):
            let cell = tableView.dequeueReusableCell(withIdentifier: "Comment", for: indexPath) as! CommentCell
            cell.topLabel.text = comment.authorScoreTimeText
            cell.bodyLabel.text = comment.body
            cell.indentationLevel = Int(comment.depth)
            cell.isExpanded = comment.isExpanded
            cell.setNeedsLayout()
            cell.layoutIfNeeded()
            return cell
        case .other(let more):
            let cell = tableView.dequeueReusableCell(withIdentifier: "More", for: indexPath) as! MoreCell
            updateMoreCell(at: indexPath, more, cell: cell)
            cell.indentationLevel = Int(more.depth)
            return cell
        }
    }
}

extension CommentsViewController: UITableViewDelegate {
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        guard !comments.isEmpty else { return 36 }
        switch comments[indexPath.row] {
        case .first: return UITableViewAutomaticDimension
        case .other: return 36
        }
    }
    
    func tableView(_ tableView: UITableView, estimatedHeightForRowAt indexPath: IndexPath) -> CGFloat {
        guard indexPath.row < comments.endIndex else { return 40 }
        guard let comment = comments[indexPath.row].first else { return 36 }
        guard comment.isExpanded else { return CommentCell.verticalMargins }
        let horizontalMargins = headerView.readableContentGuide.layoutFrame.minX * 2
        let textWidth = view.frame.width - horizontalMargins - CommentCell.indentationWidth * CGFloat(comment.depth)
        let numberOfCharacters: Int = Int(comment.body?.characters.count ?? 0)
        let averageCharacterWidth = 1.98026 / CommentCell.bodyLabelFont.pointSize
        let charactersPerLine = textWidth * averageCharacterWidth
        let numberOfNewlineCharacters = (comment.body?.components(separatedBy: .newlines).count ?? 1) - 1
        let numberOfLines = CGFloat(numberOfCharacters) / charactersPerLine
        return (ceil(numberOfLines) + CGFloat(numberOfNewlineCharacters)) * CommentCell.bodyLabelFont.lineHeight + CommentCell.verticalMargins
    }
    
    func tableView(_ tableView: UITableView, shouldHighlightRowAt indexPath: IndexPath) -> Bool {
        return !comments.isEmpty && !(comments[indexPath.row].other.map(loading.contains) ?? false)
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        switch comments[indexPath.row] {
        case .first(let comment):
            flipCellExpanded(at: indexPath, comment: comment)
        case .other(let more):
            loading.insert(more)
            updateMoreCell(at: indexPath, more)
            fetchMoreComments(using: more)
        }
        tableView.deselectRow(at: indexPath, animated: true)
    }
}

extension Either where A == Comment, B == MoreComments {
    
    var depth: Int64 {
        switch self {
        case .first(let a): return a.depth
        case .other(let b): return b.depth
        }
    }
    
    var isExpanded: Bool {
        switch self {
        case .first(let a): return a.isExpanded
        case .other: return true
        }
    }
}

func == (lhs: Either<Comment, MoreComments>, rhs: Either<Comment, MoreComments>) -> Bool {
    switch (lhs, rhs) {
    case let (.first(a), .first(b)): return a == b
    case let (.other(a), .other(b)): return a == b
    default: return false
    }
}
