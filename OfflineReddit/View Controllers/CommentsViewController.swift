//
//  CommentsViewController.swift
//  OfflineReddit
//
//  Created by Jake Bellamy on 19/03/17.
//  Copyright © 2017 Jake Bellamy. All rights reserved.
//

import UIKit

class CommentsViewController: UIViewController {
    
    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var headerView: UIView!
    @IBOutlet weak var subredditLabel: UILabel!
    @IBOutlet weak var authorTimeLabel: UILabel!
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var selfLabel: UILabel!
    
    var post: Post!
    var comments: [Comment] = []
    var allComments: [Comment] = []
    
    var isLoading = false {
        didSet {
            (tableView.cellForRow(at: IndexPath(row: comments.count, section: 0)) as? MoreCell).map(updateMoreCell)
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.rowHeight = UITableViewAutomaticDimension
        tableView.estimatedRowHeight = 50
        tableView.register(MoreCell.self, forCellReuseIdentifier: "More")
        subredditLabel.text = post.subredditNamePrefixed
        authorTimeLabel.text = post.authorTimeText
        titleLabel.text = post.title
        selfLabel.text = post.selfText
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        if let selectedIndexPath = tableView.indexPathForSelectedRow {
            tableView.deselectRow(at: selectedIndexPath, animated: animated)
        }
        if comments.isEmpty {
            comments = post.comments.sorted()
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
    
    func updateMoreCell(_ cell: MoreCell) {
        (isLoading ? cell.activityIndicator.startAnimating : cell.activityIndicator.stopAnimating)()
        cell.titleLabel.isHidden = isLoading
    }
    
    func fetchComments() {
        isLoading = true
        APIClient.shared.getComments(for: post, after: allComments.last).continueWith(.mainThread) { task -> Void in
            if let comments = task.result, !comments.isEmpty {
                let old = self.comments.count
                self.allComments += comments
                self.comments += comments
                let new = self.comments.count
                self.tableView.insertRows(at: (old..<new).map { IndexPath(row: $0, section: 0) }, with: .automatic)
            } else if let error = task.error {
                self.presentErrorAlert(error: error)
            }
            self.isLoading = false
        }
    }
}

extension CommentsViewController: UITableViewDataSource {
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return comments.count + 1
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard indexPath.row < comments.count else {
            let cell = tableView.dequeueReusableCell(withIdentifier: "More", for: indexPath) as! MoreCell
            cell.titleLabel.text = "\n" + SharedText.showMore + "\n"
            updateMoreCell(cell)
            cell.setNeedsLayout()
            cell.layoutIfNeeded()
            return cell
        }
        let cell = tableView.dequeueReusableCell(withIdentifier: "Comment", for: indexPath) as! CommentCell
        let comment = comments[indexPath.row]
        cell.topLabel.text = comment.authorTimeText
        cell.bodyLabel.text = comment.body
        cell.indentationLevel = Int(comment.depth)
        cell.layoutMargins.left = cell.bodyLabelLeading.constant + cell.contentView.layoutMargins.left
        cell.separatorInset.left = cell.layoutMargins.left
        cell.isExpanded = comment.isExpanded
        cell.setNeedsLayout()
        cell.layoutIfNeeded()
        return cell
    }
}

extension CommentsViewController: UITableViewDelegate {
    
    func tableView(_ tableView: UITableView, estimatedHeightForRowAt indexPath: IndexPath) -> CGFloat {
        guard indexPath.row < comments.endIndex else { return 50 }
        let comment = comments[indexPath.row]
        let verticalMargins: CGFloat = 30.5
        guard comment.isExpanded else { return verticalMargins }
        let horizontalMargins = headerView.readableContentGuide.layoutFrame.minX * 2
        let textWidth = view.frame.width - horizontalMargins - CGFloat(15 * comment.depth)
        let numberOfCharacters: Int = Int(comment.body?.characters.count ?? 0)
        let averageCharacterWidth = 1.98026 / CommentCell.bodyLabelFont.pointSize
        let charactersPerLine = textWidth * averageCharacterWidth
        let numberOfNewlineCharacters = (comment.body?.components(separatedBy: .newlines).count ?? 1) - 1
        let numberOfLines = CGFloat(numberOfCharacters) / charactersPerLine
        return (ceil(numberOfLines) + CGFloat(numberOfNewlineCharacters)) * CommentCell.bodyLabelFont.lineHeight + verticalMargins
    }
    
    func tableView(_ tableView: UITableView, shouldHighlightRowAt indexPath: IndexPath) -> Bool {
        return indexPath.row != comments.endIndex || !isLoading
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if indexPath.row == comments.endIndex {
            if !isLoading {
                fetchComments()
            }
        } else {
            let comment = comments[indexPath.row]
            comment.isExpanded = !comment.isExpanded
            let cell = tableView.cellForRow(at: indexPath) as? CommentCell
            cell?.isExpanded = comment.isExpanded
            cell?.isExpanding = comment.isExpanded
            
            tableView.beginUpdates()
            var delta = 0
            let indexPaths: () -> [IndexPath] = { (indexPath.row + 1..<indexPath.row + 1 + delta).map { IndexPath(row: $0, section: 0) }}
            if comment.isExpanded {
                var row = indexPath.row + 1
                if var index = allComments.index(of: comment) {
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
        }
        tableView.deselectRow(at: indexPath, animated: true)
    }
}

class CommentCell: UITableViewCell {
    @IBOutlet weak var topLabel: UILabel!
    @IBOutlet weak var bodyLabel: UILabel!
    @IBOutlet weak var bodyLabelLeading: NSLayoutConstraint!
    @IBOutlet var bodyLabelBottom: NSLayoutConstraint!
    
    static var bodyLabelFont: UIFont = .systemFont(ofSize: 14)
    
    override var indentationLevel: Int {
        didSet {
            bodyLabelLeading.constant = indentationWidth * CGFloat(indentationLevel)
        }
    }
    
    var isExpanded: Bool {
        get { return bodyLabelBottom.isActive }
        set {
            bodyLabelBottom.isActive = newValue
        }
    }
    
    var isExpanding: Bool = false
    
    override func layoutSubviews() {
        super.layoutSubviews()
        if isExpanding {
            UIView.performWithoutAnimation {
                self.contentView.layoutIfNeeded()
            }
        }
    }
}

class CommentBodyContainer: UIView {
    override func layoutSubviews() {
        UIView.performWithoutAnimation {
            super.layoutSubviews()
        }
    }
}
