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
    @IBOutlet weak var bodyTextView: UITextView!
    @IBOutlet weak var bodyLabelLeading: NSLayoutConstraint!
    @IBOutlet var bodyTextViewBottom: NSLayoutConstraint!
    @IBOutlet weak var separator: SeparatorView!
    
    var drawingContext = CommentsCellDrawingContext(previousIndentation: 0, nextIndentation: 0)
    var blockQuoteRanges: [NSRange] = []
    
    override var indentationLevel: Int {
        didSet {
            bodyLabelLeading.constant = drawingContext.indentationWidth * CGFloat(indentationLevel)
            layoutMargins.left = bodyLabelLeading.constant + contentView.layoutMargins.left
            separatorInset.left = layoutMargins.left
            setNeedsDisplay()
        }
    }
    
    var isExpanded: Bool {
        get { return bodyTextViewBottom.isActive }
        set { bodyTextViewBottom.isActive = newValue }
    }
    
    var isExpanding: Bool = false
    
    override func awakeFromNib() {
        super.awakeFromNib()
        bodyTextView.textContainerInset = .zero
        bodyTextView.textContainer.lineFragmentPadding = 0
    }
    
    override func setHighlighted(_ highlighted: Bool, animated: Bool) {
        super.setHighlighted(highlighted, animated: animated)
        setNeedsDisplay()
    }
    
    override func layoutSubviews() {
        bodyTextViewBottom.constant = bottomIndentationMargin
        super.layoutSubviews()
        if isExpanding {
            UIView.performWithoutAnimation {
                self.contentView.layoutIfNeeded()
            }
        }
    }
    
    override func draw(_ rect: CGRect) {
        drawDecorations()
        separator.isHidden = indentationLevel != 0 || drawingContext.nextIndentation != 0
        guard !blockQuoteRanges.isEmpty, isExpanded, !isExpanding,
            let context = UIGraphicsGetCurrentContext()
            else { return }
        context.setStrokeColor(UIColor.lightMidGray.cgColor)
        let lineWidth: CGFloat = 2.5
        context.setLineWidth(lineWidth)
        var origin = convert(bodyTextView.frame.origin, from: bodyTextView.superview)
        origin.x += lineWidth / 2
        for range in blockQuoteRanges {
            let glyphRange = bodyTextView.layoutManager.glyphRange(forCharacterRange: range, actualCharacterRange: nil)
            let rect = bodyTextView.layoutManager.boundingRect(forGlyphRange: glyphRange, in: bodyTextView.textContainer).insetBy(dx: 0, dy: 3.5)
            let start = CGPoint(x: origin.x, y: rect.minY + origin.y)
            let end = CGPoint(x: origin.x, y: rect.maxY + origin.y)
            context.strokeLineSegments(between: [start, end])
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
