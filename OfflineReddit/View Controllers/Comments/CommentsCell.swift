//
//  CommentsCell.swift
//  OfflineReddit
//
//  Created by Jake Bellamy on 20/03/17.
//  Copyright © 2017 Jake Bellamy. All rights reserved.
//

import UIKit

class CommentsCell: UITableViewCell, ReusableNibCell, CommentsCellDrawable {
    
    @IBOutlet weak var topLabel: UILabel!
    @IBOutlet weak var bodyLabel: URLLabel!
    @IBOutlet weak var bodyLabelLeading: NSLayoutConstraint!
    @IBOutlet var bodyLabelBottom: NSLayoutConstraint!
    @IBOutlet weak var bodyLabelHeight: NSLayoutConstraint!
    @IBOutlet weak var separator: SeparatorView!
    
    let cellBackgroundView = CommentsCellBackgroundView()
    
    override var indentationLevel: Int {
        didSet {
            bodyLabelLeading.constant = cellBackgroundView.drawingContext.indentationWidth * CGFloat(indentationLevel)
            layoutMargins.left = bodyLabelLeading.constant + contentView.layoutMargins.left
            separatorInset.left = layoutMargins.left
            separator.isHidden = cellBackgroundView.drawingContext.indentationLevel != 0
                || cellBackgroundView.drawingContext.nextIndentation != 0
        }
    }
    
    var isExpanded: Bool {
        get { return bodyLabelBottom.isActive }
        set {
            bodyLabelBottom.isActive = newValue
            bodyLabel.linkControls.forEach { $0.isHidden = !newValue }
        }
    }
    
    var isExpanding: Bool = false
    
    override func awakeFromNib() {
        super.awakeFromNib()
        backgroundView = cellBackgroundView
        cellBackgroundView.backgroundColor = .offWhite
        bodyLabel.linkControlsSuperview = contentView
        bodyLabel.isIntrinsicContentSizeEnabled = false
    }
    
    override func layoutSubviews() {
        bodyLabelBottom.constant = cellBackgroundView.drawingContext.bottomIndentationMargin
        super.layoutSubviews()
        if isExpanding {
            UIView.performWithoutAnimation {
                contentView.layoutIfNeeded()
            }
        }
    }
    
    override func setHighlighted(_ highlighted: Bool, animated: Bool) {
        super.setHighlighted(highlighted, animated: animated)
        cellBackgroundView.drawingContext.isHighlighted = highlighted
    }
    
    /*
     Laying out a self sizing cell and calling `systemLayoutSizeFitting` is not performant
     enough and results in dropped frames since it can only be called on the main thread.
     While this approach is more fragile (a change in the nib requires a change here) 
     it can be called on a background queue and is much faster overall.
     */
    struct CalculatedHeight {
        let total: CGFloat
        let topLabel: CGFloat
        let bodyLabel: CGFloat
    }
    
    static func height(
        width: CGFloat,
        topLabelText: String?,
        topLabelFont: UIFont,
        bodyLabelText: NSAttributedString?,
        drawingContext: CommentsCellDrawingContext,
        isExpanded: Bool
        ) -> CalculatedHeight {
        
        let textContainer = NSTextContainer(size: CGSize(width: width - drawingContext.leftIndentationMargin, height: 0))
        textContainer.lineFragmentPadding = 0
        let layoutManager = NSLayoutManager()
        layoutManager.addTextContainer(textContainer)
        let textStorage = NSTextStorage()
        textStorage.addLayoutManager(layoutManager)
        
        func calculateHeight() -> CGFloat {
            return layoutManager.boundingRect(
                forGlyphRange: layoutManager.glyphRange(for: textContainer),
                in: textContainer).height
        }
        
        let margin: CGFloat = 8
        
        let topLabelHeight: CGFloat = topLabelText.map {
            textContainer.maximumNumberOfLines = 1
            textStorage.setAttributedString(NSAttributedString(
                string: $0,
                attributes: [NSFontAttributeName: topLabelFont]))
            return calculateHeight()
            } ?? 0
        
        let bodyLabelHeight: CGFloat = !isExpanded ? 0 :
            bodyLabelText.map {
                textContainer.maximumNumberOfLines = 0
                textStorage.setAttributedString($0)
                return calculateHeight()
            } ?? 0
        
        let total = topLabelHeight
            + bodyLabelHeight
            + (margin * 2)
            + drawingContext.bottomIndentationMargin
        
        return CalculatedHeight(
            total: total,
            topLabel: topLabelHeight,
            bodyLabel: bodyLabelHeight)
    }
}

class CommentBodyContainer: UIView {
    override func layoutSubviews() {
        UIView.performWithoutAnimation {
            super.layoutSubviews()
        }
    }
}
