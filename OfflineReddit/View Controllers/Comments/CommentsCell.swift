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
    @IBOutlet weak var bodyTextView: URLTextView!
    @IBOutlet weak var bodyLabelLeading: NSLayoutConstraint!
    @IBOutlet var bodyTextViewBottom: NSLayoutConstraint!
    @IBOutlet weak var separator: SeparatorView!
    
    var drawingContext = CommentsCellDrawingContext(previousIndentation: 0, nextIndentation: 0)
    
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
    }
}

class CommentBodyContainer: UIView {
    override func layoutSubviews() {
        UIView.performWithoutAnimation {
            super.layoutSubviews()
        }
    }
}
