//
//  CommentsDataSource.swift
//  OfflineReddit
//
//  Created by Jake Bellamy on 9/05/17.
//  Copyright © 2017 Jake Bellamy. All rights reserved.
//

import UIKit
import BoltsSwift
import CocoaMarkdown

protocol CommentsDataSourceDelegate: class {
    func viewDimensionsForCommentsDataSource(_ dataSource: CommentsDataSource) -> (horizontalMargins: CGFloat, frameWidth: CGFloat)
    func commentsDataSource(_ dataSource: CommentsDataSource, isFetchingWith task: Task<Void>)
    func commentsDataSource(_ dataSource: CommentsDataSource, didUpdateAllCommentsWith saved: Int64, _ toExpand: Int64)
}

class CommentsDataSource: NSObject {
    
    weak var tableView: UITableView?
    
    // MARK: - Init
    
    let post: Post
    let provider: CommentsProvider
    let reachability: Reachability
    
    init(post: Post, provider: DataProvider) {
        self.post = post
        self.provider = CommentsProvider(provider: provider)
        self.reachability = provider.reachability
        super.init()
        NotificationCenter.default.addObserver(self, selector: #selector(reachabilityChanged(_:)), name: .ReachabilityChanged, object: nil)
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    // MARK: -
    
    /// Master list of all the comments available to display, before filtering.
    var allComments: [CommentsCellModel] = []
    
    /// List of comments which drives the table view. Is a subset of `allComments` when a comment is condensed and its children hidden.
    private(set) var comments: [CommentsCellModel] = []
    
    /// The 'more comments' cells which are loading their children.
    var loadingCells: Set<MoreComments> = []
    
    var sort = Defaults.commentsSort {
        didSet { updateComments() }
    }
    
    weak var delegate: CommentsDataSourceDelegate?
    
    static let commentSizingCell = CommentsCell.instantiateFromNib()
    
    func indexPath(of more: MoreComments) -> IndexPath? {
        return comments.index(where: { $0.comment == more })
            .map { IndexPath(row: $0, section: 0) }
    }
    
    private func animateCommentsUpdate() {
        tableView?.reload(
            get: { comments },
            update: updateComments)
    }
    
    private func updateComments() {
        allComments = {
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
        updateExpanded(for: comment, at: indexPath)
        cell?.isExpanding = false
        tableView?.scrollToRow(at: indexPath, at: .none, animated: true)
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
        tableView?.endUpdates()
    }
    
    // MARK: - Fetching
    
    @discardableResult
    func fetchCommentsIfNeeded() -> Task<Void>? {
        if allComments.isEmpty {
            updateComments()
        }
        if allComments.isEmpty {
            return fetchComments()
        }
        return nil
    }
    
    func fetchComments() -> Task<Void> {
        return provider.getComments(for: post, sortedBy: sort).continueOnSuccessWith(.mainThread) { _ in
            self.animateCommentsUpdate()
            self.provider.local.trySave()
        }
    }
    
    @discardableResult
    func fetchMoreComments(using more: MoreComments) -> Task<[Comment]> {
        let task = provider.getMoreComments(using: [more], post: post, sortedBy: sort).continueWithTask(.mainThread) {
            self.didFetchMoreComments(more, task: $0)
        }
        delegate?.commentsDataSource(self, isFetchingWith: task.asVoid())
        return task
    }
    
    private func didFetchMoreComments(_ more: MoreComments, task: Task<[Comment]>) -> Task<[Comment]> {
        loadingCells.remove(more)
        if task.error == nil {
            self.animateCommentsUpdate()
        } else {
            let cell = indexPath(of: more).flatMap {
                tableView?.cellForRow(at: $0) as? MoreCommentsCell
            }
            updateMoreCell(cell, more)
        }
        return task
    }
    
    // MARK: Offline saving
    
    private(set) var downloader: CommentsDownloader?
    
    @discardableResult
    func startDownload(updating tableView: UITableView) -> Task<Void> {
        let downloader = CommentsDownloader(post: post, comments: allComments.flatMap { $0.comment.other }, remote: provider.remote, sort: sort)
        self.downloader = downloader
        
        return downloader.start().continueWithTask(.mainThread) {
            self.downloader = nil
            self.updateComments()
            tableView.reloadData()
            self.provider.local.trySave()
            return $0
        }
    }
    
    // MARK: - Reachability
    
    func reachabilityChanged(_ notification: Notification) {
        animateCommentsUpdate()
    }
}

// MARK: - Table view data source

extension CommentsDataSource: UITableViewDataSource {
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return max(1, comments.count)
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard !comments.isEmpty else {
            return configureMoreCommentsCell(tableView.dequeueReusableCell(for: indexPath), model: nil)
        }
        
        let model = comments[indexPath.row]
        return model.isMoreComments
            ? configureMoreCommentsCell(tableView.dequeueReusableCell(for: indexPath), model: model)
            : configureCommentCell(tableView.dequeueReusableCell(for: indexPath), model: model)
    }
    
    func configureCommentCell(_ cell: CommentsCell, model: CommentsCellModel) -> CommentsCell {
        let comment = model.comment.first
        cell.topLabel.text = comment?.authorScoreTimeText
        cell.bodyLabel.attributedText = model.attributedText ?? {
            let data = comment?.body?.data(using: .utf8)
            let attributedText = CMDocument(data: data, options: [])
                .attributedString(with: CMTextAttributes())
            model.attributedText = attributedText
            return attributedText
        }()
        cell.indentationLevel = Int(model.depth)
        cell.isExpanded = model.isExpanded
        return cell
    }
    
    func configureMoreCommentsCell(_ cell: MoreCommentsCell, model: CommentsCellModel?) -> MoreCommentsCell {
        updateMoreCell(cell, model?.comment.other, forceLoad: model == nil)
        cell.indentationLevel = Int(model?.depth ?? 0)
        return cell
    }
    
    func configureExpandedHeight(for model: CommentsCellModel, width: CGFloat) -> CGFloat {
        let cell = configureCommentCell(CommentsDataSource.commentSizingCell, model: model)
        cell.setNeedsLayout()
        cell.layoutIfNeeded()
        let height = cell.systemLayoutSizeFitting(
            CGSize(width: width, height: UILayoutFittingCompressedSize.height),
            withHorizontalFittingPriority: UILayoutPriorityRequired,
            verticalFittingPriority: UILayoutPriorityFittingSizeLevel).height
        model.expandedHeight[width] = height
        return height
    }
}

// MARK: - Table view delegate

extension CommentsDataSource: UITableViewDelegate {
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        guard !comments.isEmpty else { return CommentsCellModel.moreCommentsHeight }
        guard let width = tableView.superview?.frame.width else { return 0 }
        let model = comments[indexPath.row]
        return model.height(for: width) ?? configureExpandedHeight(for: model, width: width)
    }
    
    func tableView(_ tableView: UITableView, estimatedHeightForRowAt indexPath: IndexPath) -> CGFloat {
        guard indexPath.row < comments.endIndex else { return 40 }
        let model = comments[indexPath.row]
        guard let comment = model.comment.first else { /* 'More comments' */ return CommentsCellModel.moreCommentsHeight }
        guard model.isExpanded else { return CommentsCellModel.condensedHeight }
        guard let (margin, frameWidth) = delegate?.viewDimensionsForCommentsDataSource(self) else { return 0 }
        let textWidth = frameWidth - margin - CommentsCell.indentationWidth * CGFloat(comment.depth)
        let numberOfCharacters: Int = Int(comment.body?.characters.count ?? 0)
        let averageCharacterWidth = 1.98026 / CommentsCell.bodyLabelFont.pointSize
        let charactersPerLine = textWidth * averageCharacterWidth
        let numberOfNewlineCharacters = (comment.body?.components(separatedBy: .newlines).count ?? 1) - 1
        let numberOfLines = CGFloat(numberOfCharacters) / charactersPerLine
        return (ceil(numberOfLines) + CGFloat(numberOfNewlineCharacters)) * CommentsCell.bodyLabelFont.lineHeight + CommentsCellModel.condensedHeight
    }
    
    func tableView(_ tableView: UITableView, shouldHighlightRowAt indexPath: IndexPath) -> Bool {
        return !comments.isEmpty && !(comments[indexPath.row].comment.other.map(loadingCells.contains) ?? false)
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let model = comments[indexPath.row]
        switch model.comment {
        case .first:
            flipCommentExpanded(for: model, at: indexPath)
        case .other(let more):
            loadingCells.insert(more)
            updateMoreCell(tableView.cellForRow(at: indexPath) as? MoreCommentsCell, more)
            fetchMoreComments(using: more)
        }
        tableView.deselectRow(at: indexPath, animated: true)
    }
}
