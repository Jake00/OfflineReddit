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
        NotificationCenter.default.addObserver(self, selector: #selector(preferredTextSizeChanged(_:)), name: .UIContentSizeCategoryDidChange, object: nil)
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
    
    struct SizingCell {
        static let comment = CommentsCell.instantiateFromNib()
        static let moreComments = MoreCommentsCell.instantiateFromNib()
    }
    
    var textAttributes: CMTextAttributes = {
        let textAttributes = CMTextAttributes()
        textAttributes.blockQuoteAttributes = [
            NSFontAttributeName: UIFont.preferredFont(forTextStyle: .body),
            NSForegroundColorAttributeName: UIColor.lightMidGray,
            NSParagraphStyleAttributeName: {
                let paragraph = NSMutableParagraphStyle()
                paragraph.firstLineHeadIndent = 7
                paragraph.headIndent = 7
                paragraph.paragraphSpacingBefore = 4
                return paragraph
            }()
        ]
        textAttributes.textAttributes = [
            NSFontAttributeName: UIFont.preferredFont(forTextStyle: .body),
            NSForegroundColorAttributeName: UIColor.offBlack
        ]
        return textAttributes
    }()
    
    func indexPath(of more: MoreComments) -> IndexPath? {
        return comments.index(where: { $0.comment == more })
            .map { IndexPath(row: $0, section: 0) }
    }
    
    private func animateCommentsUpdate(fromSuccessfulFetch: Bool = false) {
        tableView?.reload(
            get: { comments },
            update: { updateComments(fromSuccessfulFetch: fromSuccessfulFetch) })
    }
    
    private func updateComments(fromSuccessfulFetch: Bool = false) {
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
        updateDrawable(tableView?.cellForRow(at: indexPath) as? CommentsCellDrawable, at: indexPath, model: comment)
        tableView?.endUpdates()
    }
    
    // MARK: - Cell configuration
    
    func configureCommentCell(_ cell: CommentsCell, at indexPath: IndexPath, model: CommentsCellModel) -> CommentsCell {
        let comment = model.comment.first
        cell.topLabel.text = comment?.authorScoreTimeText
        cell.topLabel.font = .preferredFont(forTextStyle: .footnote)
        let render: CMAttributedStringRenderResult? = model.render ?? {
            guard let data = comment?.body?.data(using: .utf8) else { return nil }
            let render = CMDocument(data: data, options: [])
                .attributedString(with: textAttributes)
            model.render = render
            return render
        }()
        cell.bodyTextView.attributedText = render?.result
        cell.blockQuoteRanges = render?.blockQuoteRanges.map { $0.rangeValue } ?? []
        cell.isExpanded = model.isExpanded
        updateDrawable(cell, at: indexPath, model: model)
        return cell
    }
    
    func configureMoreCommentsCell(_ cell: MoreCommentsCell, at indexPath: IndexPath?, model: CommentsCellModel?) -> MoreCommentsCell {
        updateMoreCell(cell, model?.comment.other, forceLoad: model == nil)
        updateDrawable(cell, at: indexPath, model: model)
        cell.titleLabel.font = .preferredFont(forTextStyle: .footnote, weight: .semibold)
        return cell
    }
    
    func updateDrawable(_ cell: CommentsCellDrawable?, at indexPath: IndexPath?, model: CommentsCellModel?) {
        let level = Int(model?.depth ?? 0)
        cell?.indentationLevel = level
        cell?.drawingContext.previousIndentation = indexPath.flatMap {
            $0.row > comments.startIndex ? Int(comments[$0.row - 1].depth) : nil
            } ?? level
        cell?.drawingContext.nextIndentation = indexPath.flatMap {
            $0.row + 1 < comments.endIndex ? Int(comments[$0.row + 1].depth) : nil
            } ?? level
    }
    
    func configureHeight(for model: CommentsCellModel, at indexPath: IndexPath, width: CGFloat) -> CGFloat {
        let height: CGFloat
        let cell: CommentsCellDrawable
        if model.isMoreComments {
            cell = configureMoreCommentsCell(SizingCell.moreComments, at: indexPath, model: model)
            height = MoreCommentsCell.standardHeight
        } else {
            let _cell = configureCommentCell(SizingCell.comment, at: indexPath, model: model)
            _cell.setNeedsLayout()
            _cell.layoutIfNeeded()
            cell = _cell
            height = _cell.systemLayoutSizeFitting(
                CGSize(width: width, height: UILayoutFittingCompressedSize.height),
                withHorizontalFittingPriority: UILayoutPriorityRequired,
                verticalFittingPriority: UILayoutPriorityFittingSizeLevel).height
        }
        if model.isExpanded {
            model.expandedHeight[width] = height + cell.bottomIndentationMargin
        } else {
            CommentsCellModel.condensedHeight = height
        }
        return height
    }
    
    // MARK: - Fetching
    
    fileprivate var hasFetchedOnceSuccessfully = false
    
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
            self.animateCommentsUpdate(fromSuccessfulFetch: true)
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
    
    // MARK: - Offline saving
    
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
    
    // MARK: - Dynamic type 
    
    func preferredTextSizeChanged(_ notification: Notification) {
        textAttributes = CMTextAttributes()
        CommentsCellModel.condensedHeight = nil
        for model in allComments {
            model.render = nil
            model.expandedHeight.removeAll()
        }
        tableView?.reloadData()
    }
}

// MARK: - Table view data source

extension CommentsDataSource: UITableViewDataSource {
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return max(hasFetchedOnceSuccessfully ? 0 : 1, comments.count)
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard !comments.isEmpty else {
            return configureMoreCommentsCell(tableView.dequeueReusableCell(for: indexPath), at: indexPath, model: nil)
        }
        
        let model = comments[indexPath.row]
        return model.isMoreComments
            ? configureMoreCommentsCell(tableView.dequeueReusableCell(for: indexPath), at: indexPath, model: model)
            : configureCommentCell(tableView.dequeueReusableCell(for: indexPath), at: indexPath, model: model)
    }
}

// MARK: - Table view delegate

extension CommentsDataSource: UITableViewDelegate {
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        guard !comments.isEmpty else { return MoreCommentsCell.standardHeight }
        guard let width = tableView.superview?.frame.width else { return 0 }
        let model = comments[indexPath.row]
        return model.height(for: width) ?? configureHeight(for: model, at: indexPath, width: width)
    }
    
    func tableView(_ tableView: UITableView, estimatedHeightForRowAt indexPath: IndexPath) -> CGFloat {
        guard indexPath.row < comments.endIndex else { return 40 }
        guard let width = tableView.superview?.frame.width else { return 0 }
        let model = comments[indexPath.row]
        if let height = model.height(for: width) { return height }
        guard let comment = model.comment.first else { return MoreCommentsCell.standardHeight }
        guard model.isExpanded else { return CommentsCellModel.condensedHeight ?? configureHeight(for: model, at: indexPath, width: width) }
        guard let (margin, frameWidth) = delegate?.viewDimensionsForCommentsDataSource(self) else { return 0 }
        let textWidth = frameWidth - margin - SizingCell.comment.drawingContext.indentationWidth * CGFloat(comment.depth)
        let numberOfCharacters: Int = Int(comment.body?.characters.count ?? 0)
        let font = textAttributes.textAttributes[NSFontAttributeName] as? UIFont
            ?? UIFont.preferredFont(forTextStyle: .body)
        let averageCharacterWidth = 1.98026 / font.pointSize
        let charactersPerLine = textWidth * averageCharacterWidth
        let numberOfNewlineCharacters = (comment.body?.components(separatedBy: .newlines).count ?? 1) - 1
        let numberOfLines = CGFloat(numberOfCharacters) / charactersPerLine
        let bodyHeight = (ceil(numberOfLines) + CGFloat(numberOfNewlineCharacters)) * font.lineHeight
        let topHeight = CommentsCellModel.condensedHeight ?? {
            let wasExpanded = model.isExpanded
            defer { model.isExpanded = wasExpanded }
            model.isExpanded = false
            return configureHeight(for: model, at: indexPath, width: width)
        }()
        return bodyHeight + topHeight
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
