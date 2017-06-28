//
//  CommentsDataSource+TableView.swift
//  OfflineReddit
//
//  Created by Jake Bellamy on 28/06/17.
//  Copyright © 2017 Jake Bellamy. All rights reserved.
//

import UIKit

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
        // 'Load more' cell at end of rows
        guard indexPath.row < comments.endIndex else { return MoreCommentsCell.standardHeight }
        
        let model = comments[indexPath.row]
        guard let width = tableView.superview?.frame.width else { return 0 }
        
        // Use the cached height if we've already calculated it
        if let height = model.height(for: width) {
            return height
        }
        
        // Only estimate comment cells, 'more comment' cells are the same height
        guard let comment = model.comment.first else { return MoreCommentsCell.standardHeight }
        
        // When a comment cell is condensed we don't need to estimate its body label
        guard model.isExpanded else {
            return CommentsCellModel.condensedHeight
                ?? configureHeight(for: model, at: indexPath, width: width)
        }
        
        return estimatedHeight(
            for: comment,
            model: model,
            at: indexPath,
            width: width)
    }
    
    func estimatedHeight(
        for comment: Comment,
        model: CommentsCellModel,
        at indexPath: IndexPath,
        width: CGFloat
        ) -> CGFloat {
        
        guard let (margin, frameWidth) = delegate?.viewDimensionsForCommentsDataSource(self)
            else { return 0 }
        
        let textWidth = frameWidth - margin - 10 * CGFloat(comment.depth)
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

// MARK: - Table view prefetching

extension CommentsDataSource: UITableViewDataSourcePrefetching {
    
    func tableView(_ tableView: UITableView, prefetchRowsAt indexPaths: [IndexPath]) {
        guard let width = tableView.superview?.frame.width else { return }
        let toCache: [(IndexPath, CommentsCellModel)] = indexPaths.flatMap {
            let model = comments[$0.row]
            return model.height(for: width) == nil ? ($0, model) : nil
        }
        guard !toCache.isEmpty else { return }
        heightCachingQueue.async {
            for (indexPath, model) in toCache {
                _ = self.configureHeight(for: model, at: indexPath, width: width)
            }
        }
    }
}
