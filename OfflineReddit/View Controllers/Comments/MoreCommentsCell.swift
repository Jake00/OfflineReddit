//
//  MoreCommentsCell.swift
//  OfflineReddit
//
//  Created by Jake Bellamy on 19/05/17.
//  Copyright © 2017 Jake Bellamy. All rights reserved.
//

import UIKit

class MoreCommentsCell: UITableViewCell, ReusableNibCell, CommentsCellDrawable {
    
    @IBOutlet var titleLabel: UILabel!
    @IBOutlet var activityIndicator: UIActivityIndicatorView!
    @IBOutlet weak var containerLeading: NSLayoutConstraint!
    @IBOutlet weak var container: UIView!
    
    var drawingContext = CommentsCellDrawingContext(previousIndentation: 0, nextIndentation: 0)
    
    override var indentationLevel: Int {
        didSet {
            let indentation = CommentsCell.indentationWidth * CGFloat(indentationLevel)
            containerLeading.constant = indentation
            layoutMargins.left = indentation + contentView.layoutMargins.left
            separatorInset.left = layoutMargins.left
            setNeedsDisplay()
        }
    }
    
    override func setHighlighted(_ highlighted: Bool, animated: Bool) {
        super.setHighlighted(highlighted, animated: animated)
        setNeedsDisplay()
    }
    
    override func draw(_ rect: CGRect) {
        drawDecorations()
    }
}
