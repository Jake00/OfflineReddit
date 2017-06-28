//
//  CommentsDataSource+CellConfiguration.swift
//  OfflineReddit
//
//  Created by Jake Bellamy on 29/06/17.
//  Copyright © 2017 Jake Bellamy. All rights reserved.
//

import UIKit
import CocoaMarkdown.CMAttributedStringRenderResult

extension CommentsDataSource {
    
    func commentCellConfigurable(
        model: CommentsCellModel
        ) -> (String?, UIFont, CMAttributedStringRenderResult?) {
        
        let comment = model.comment.first
        let topLabelText = comment?.authorScoreTimeText
        let topLabelFont = UIFont.preferredFont(forTextStyle: .footnote)
        let render: CMAttributedStringRenderResult? = model.render ?? {
            guard let data = comment?.body?.data(using: .utf8) else { return nil }
            let render = CMDocument(data: data, options: [])
                .attributedString(with: textAttributes)
            model.render = render
            return render
            }()
        return (topLabelText, topLabelFont, render)
    }
    
    func configureCommentCell(
        _ cell: CommentsCell,
        at indexPath: IndexPath,
        model: CommentsCellModel
        ) -> CommentsCell {
        
        let (topLabelText, topLabelFont, render) = commentCellConfigurable(model: model)
        cell.topLabel.text = topLabelText
        cell.topLabel.font = topLabelFont
        cell.bodyLabel.attributedText = render?.result
        cell.bodyLabel.blockQuoteRanges = render?.blockQuoteRanges.map { $0.rangeValue } ?? []
        cell.bodyLabel.textRectCache = textRectCache
        cell.bodyLabel.linkAttributes = textAttributes.linkAttributes
        cell.bodyLabel.delegate = urlLabelDelegate
        cell.isExpanded = model.isExpanded
        let width = tableView?.superview?.frame.width ?? 0
        cell.bodyLabelHeight.constant = model.bodyLabelHeight[width] ?? 0
        updateDrawable(cell, at: indexPath, model: model)
        return cell
    }
    
    func configureMoreCommentsCell(
        _ cell: MoreCommentsCell,
        at indexPath: IndexPath?,
        model: CommentsCellModel?
        ) -> MoreCommentsCell {
        
        updateMoreCell(cell, model?.comment.other, forceLoad: model == nil)
        updateDrawable(cell, at: indexPath, model: model)
        cell.titleLabel.font = .preferredFont(forTextStyle: .footnote, weight: .semibold)
        return cell
    }
    
    func updateDrawable(
        _ cell: CommentsCellDrawable?,
        at indexPath: IndexPath?,
        model: CommentsCellModel?
        ) {
        
        cell?.cellBackgroundView.drawingContext = cellDrawingContext(at: indexPath, with: model)
    }
    
    func cellDrawingContext(
        at indexPath: IndexPath?,
        with model: CommentsCellModel?
        ) -> CommentsCellDrawingContext {
        
        let row = indexPath?.row ?? 0
        let level = Int(model?.depth ?? 0)
        return CommentsCellDrawingContext(
            indentationLevel: level,
            previousIndentation: row > comments.startIndex ? Int(comments[row - 1].depth) : level,
            nextIndentation: row + 1 < comments.endIndex ? Int(comments[row + 1].depth) : level,
            isHighlighted: false)
    }
    
    func configureHeight(
        for model: CommentsCellModel,
        at indexPath: IndexPath,
        width: CGFloat
        ) -> CGFloat {
        
        let height: CGFloat
        let drawingContext = cellDrawingContext(at: indexPath, with: model)
        if model.isMoreComments {
            height = MoreCommentsCell.standardHeight + drawingContext.bottomIndentationMargin
        } else {
            let (topLabelText, topLabelFont, render) = commentCellConfigurable(model: model)
            let margin = delegate?.viewDimensionsForCommentsDataSource(self).horizontalMargins ?? 0
            let context = CommentsCell.HeightCalculationContext(
                width: width - margin,
                topLabelText: topLabelText,
                topLabelFont: topLabelFont,
                bodyLabelText: render?.result,
                drawingContext: drawingContext,
                isExpanded: model.isExpanded)
            let cellHeight = CommentsCell.height(using: context)
            height = cellHeight.total
            model.bodyLabelHeight[width] = cellHeight.bodyLabel
        }
        if model.isExpanded {
            model.expandedHeight[width] = height
        } else {
            CommentsCellModel.condensedHeight = height
        }
        return height
    }
}
