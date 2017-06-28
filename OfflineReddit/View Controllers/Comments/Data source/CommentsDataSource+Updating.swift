//
//  CommentsDataSource+Updating.swift
//  OfflineReddit
//
//  Created by Jake Bellamy on 29/06/17.
//  Copyright © 2017 Jake Bellamy. All rights reserved.
//

import UIKit

extension CommentsDataSource {
    
    func animateCommentsUpdate(fromSuccessfulFetch: Bool = false) {
        tableView?.reload(
            get: { comments },
            update: { updateComments(fromSuccessfulFetch: fromSuccessfulFetch) })
    }
    
    func updateComments(fromSuccessfulFetch: Bool = false) {
        allComments = {
            // These set mutations keep the old models and therefore their states, in
            // order for previously condensed comment cells to not reexpand by the update.
            var updating = Set(allComments)
            let new = Set({ () -> [CommentsCellModel] in
                let models = post.displayComments.map(CommentsCellModel.init)
                return reachability.isOnline ? models : models.filter { !$0.isMoreComments }
                }())
            updating.formUnion(new)
            updating.formIntersection(new)
            return updating.sorted(by: sort)
        }()
        var condensed: Comment?
        comments = allComments.filter { next in
            if let comment = condensed {
                let isSibling = next.depth > comment.depth
                if !isSibling {
                    condensed = nil
                }
                return !isSibling
            } else if !next.isExpanded {
                condensed = next.comment.first
            }
            return true
        }
        if fromSuccessfulFetch {
            hasFetchedOnceSuccessfully = true
        }
        if let delegate = delegate {
            let (saved, toExpand) = allComments.reduce((0, 0) as (Int64, Int64)) {
                switch $1.comment {
                case .first: return ($0.0 + 1, $0.1)
                case .other(let b): return ($0.0, $0.1 + b.count)
                }
            }
            delegate.commentsDataSource(self, didUpdateAllCommentsWith: saved, toExpand)
        }
    }
    
    func updateMoreCell(_ cell: MoreCommentsCell?, _ more: MoreComments? = nil, forceLoad: Bool = false) {
        let isLoading = forceLoad || (more.map(loadingCells.contains) ?? false)
        cell?.titleLabel.text = isLoading
            ? SharedText.loadingCaps
            : String.localizedStringWithFormat(SharedText.repliesFormat, more?.count ?? 0)
        cell?.activityIndicator.setAnimating(isLoading)
    }
    
    func flipCommentExpanded(for comment: CommentsCellModel, at indexPath: IndexPath) {
        comment.isExpanded = !comment.isExpanded
        let cell = tableView?.cellForRow(at: indexPath) as? CommentsCell
        cell?.isExpanded = comment.isExpanded
        cell?.isExpanding = comment.isExpanded
        CATransaction.begin()
        CATransaction.setCompletionBlock {
            cell?.isExpanding = false
            cell?.setNeedsDisplay()
        }
        updateExpanded(for: comment, at: indexPath)
        tableView?.scrollToRow(at: indexPath, at: .none, animated: true)
        CATransaction.commit()
    }
    
    func updateExpanded(for comment: CommentsCellModel, at indexPath: IndexPath) {
        tableView?.beginUpdates()
        var delta = 0
        let makeIndexPaths: () -> [IndexPath] = {
            (indexPath.row + 1..<indexPath.row + 1 + delta).map {
                IndexPath(row: $0, section: 0)
            }
        }
        if comment.isExpanded {
            /* Row is expanding, add the children for this comment. */
            var row = indexPath.row + 1
            if var index = allComments.index(of: comment) {
                while index + 1 < allComments.endIndex,
                    comment.depth < allComments[index + 1].depth,
                    allComments[index].isExpanded {
                        comments.insert(allComments[index + 1], at: row)
                        row += 1; index += 1; delta += 1
                }
                if delta > 0 {
                    tableView?.insertRows(at: makeIndexPaths(), with: .fade)
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
                tableView?.deleteRows(at: makeIndexPaths(), with: .fade)
            }
        }
        updateDrawable(tableView?.cellForRow(at: indexPath) as? CommentsCellDrawable, at: indexPath, model: comment)
        tableView?.endUpdates()
    }
}
