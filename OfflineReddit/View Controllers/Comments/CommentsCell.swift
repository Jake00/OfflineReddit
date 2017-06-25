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
        cellBackgroundView.contentMode = .redraw
        cellBackgroundView.backgroundColor = .offWhite
        bodyLabel.linkControlsSuperview = contentView
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
}

class CommentBodyContainer: UIView {
    override func layoutSubviews() {
        UIView.performWithoutAnimation {
            super.layoutSubviews()
        }
    }
}
