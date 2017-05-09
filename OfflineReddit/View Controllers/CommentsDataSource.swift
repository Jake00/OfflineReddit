//
//  CommentsDataSource.swift
//  OfflineReddit
//
//  Created by Jake Bellamy on 9/05/17.
//  Copyright © 2017 Jake Bellamy. All rights reserved.
//

import UIKit

protocol CommentsDataSourceDelegate: class {
    var viewHorizontalMargins: CGFloat { get }
    var viewFrameWidth: CGFloat { get }
    func didSelectMoreComments(_ more: MoreComments)
}

class CommentsDataSource: NSObject {
    
    var allComments: [Either<Comment, MoreComments>] = [] {
        didSet { updateComments() }
    }
    private(set) var comments: [Either<Comment, MoreComments>] = []
    var loadingCells: Set<MoreComments> = []
    
    weak var delegate: CommentsDataSourceDelegate?
    
    func indexPath(of more: MoreComments) -> IndexPath? {
        let v = Either<Comment, MoreComments>.other(more)
        return comments.index(where: { $0 == v })
            .map { IndexPath(row: $0, section: 0) }
    }
    
    private func updateComments() {
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
    }
    
    func updateMoreCell(_ cell: MoreCell?, _ more: MoreComments? = nil, forceLoad: Bool = false) {
        let isLoading = forceLoad || (more.map(loadingCells.contains) ?? false)
        cell?.titleLabel.text = isLoading
            ? SharedText.loadingCaps
            : String.localizedStringWithFormat(SharedText.repliesFormat, more?.count ?? 0)
        cell?.activityIndicator.setAnimating(isLoading)
    }
    
    func flipCommentExpanded(for comment: Comment, at indexPath: IndexPath, in tableView: UITableView) {
        comment.isExpanded = !comment.isExpanded
        let cell = tableView.cellForRow(at: indexPath) as? CommentCell
        cell?.isExpanded = comment.isExpanded
        cell?.isExpanding = comment.isExpanded
        updateExpanded(for: comment, at: indexPath, in: tableView)
        cell?.isExpanding = false
        tableView.scrollToRow(at: indexPath, at: .none, animated: true)
    }
    
    func updateExpanded(for comment: Comment, at indexPath: IndexPath, in tableView: UITableView) {
        tableView.beginUpdates()
        var delta = 0
        let makeIndexPaths: () -> [IndexPath] = {
            (indexPath.row + 1..<indexPath.row + 1 + delta).map {
                IndexPath(row: $0, section: 0)
            }
        }
        if comment.isExpanded {
            /* Row is expanding, add the children for this comment. */
            var row = indexPath.row + 1
            if var index = allComments.index(where: { $0.first == comment }) {
                while index + 1 < allComments.endIndex,
                    comment.depth < allComments[index + 1].depth,
                    allComments[index].isExpanded {
                        comments.insert(allComments[index + 1], at: row)
                        row += 1; index += 1; delta += 1
                }
                if delta > 0 {
                    tableView.insertRows(at: makeIndexPaths(), with: .fade)
                }
            }
        } else {
            /* Row is contracting, remove the children from this comment. */
            while indexPath.row + 1 < comments.endIndex,
                comment.depth < comments[indexPath.row + 1].depth {
                    comments.remove(at: indexPath.row + 1)
                    delta += 1
            }
            if delta > 0 {
                tableView.deleteRows(at: makeIndexPaths(), with: .fade)
            }
        }
        tableView.endUpdatesSafe()
    }
}

// MARK: - Table view data source

extension CommentsDataSource: UITableViewDataSource {
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return max(1, comments.count)
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard !comments.isEmpty else {
            let cell = tableView.dequeueReusableCell(withIdentifier: "More", for: indexPath) as! MoreCell
            updateMoreCell(cell, forceLoad: true)
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
            updateMoreCell(cell, more)
            cell.indentationLevel = Int(more.depth)
            return cell
        }
    }
}

// MARK: - Table view delegate

extension CommentsDataSource: UITableViewDelegate {
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        guard !comments.isEmpty else { return 36 }
        switch comments[indexPath.row] {
        case .first: return UITableViewAutomaticDimension
        case .other: return 36
        }
    }
    
    func tableView(_ tableView: UITableView, estimatedHeightForRowAt indexPath: IndexPath) -> CGFloat {
        guard indexPath.row < comments.endIndex else { return 40 }
        guard let comment = comments[indexPath.row].first else { /* 'More comments' */ return 36 }
        guard comment.isExpanded else { return CommentCell.verticalMargins }
        guard let delegate = delegate else { return 0 }
        let textWidth = delegate.viewFrameWidth - delegate.viewHorizontalMargins - CommentCell.indentationWidth * CGFloat(comment.depth)
        let numberOfCharacters: Int = Int(comment.body?.characters.count ?? 0)
        let averageCharacterWidth = 1.98026 / CommentCell.bodyLabelFont.pointSize
        let charactersPerLine = textWidth * averageCharacterWidth
        let numberOfNewlineCharacters = (comment.body?.components(separatedBy: .newlines).count ?? 1) - 1
        let numberOfLines = CGFloat(numberOfCharacters) / charactersPerLine
        return (ceil(numberOfLines) + CGFloat(numberOfNewlineCharacters)) * CommentCell.bodyLabelFont.lineHeight + CommentCell.verticalMargins
    }
    
    func tableView(_ tableView: UITableView, shouldHighlightRowAt indexPath: IndexPath) -> Bool {
        return !comments.isEmpty && !(comments[indexPath.row].other.map(loadingCells.contains) ?? false)
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        switch comments[indexPath.row] {
        case .first(let comment):
            flipCommentExpanded(for: comment, at: indexPath, in: tableView)
        case .other(let more):
            loadingCells.insert(more)
            updateMoreCell(tableView.cellForRow(at: indexPath) as? MoreCell, more)
            delegate?.didSelectMoreComments(more)
        }
        tableView.deselectRow(at: indexPath, animated: true)
    }
}
