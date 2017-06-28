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
    @IBOutlet weak var containerBottom: NSLayoutConstraint!
    @IBOutlet weak var container: UIView!
    
    let cellBackgroundView = CommentsCellBackgroundView()
    
    static let standardHeight: CGFloat = 36
    
    override var indentationLevel: Int {
        didSet {
            let indentation = cellBackgroundView.drawingContext.indentationWidth * CGFloat(indentationLevel)
            containerLeading.constant = indentation
            layoutMargins.left = indentation + contentView.layoutMargins.left
            separatorInset.left = layoutMargins.left
        }
    }
    
    override func awakeFromNib() {
        super.awakeFromNib()
        backgroundView = cellBackgroundView
        cellBackgroundView.backgroundColor = .offWhite
    }
    
    override func layoutSubviews() {
        containerBottom.constant = cellBackgroundView.drawingContext.bottomIndentationMargin
        super.layoutSubviews()
    }
    
    override func setHighlighted(_ highlighted: Bool, animated: Bool) {
        super.setHighlighted(highlighted, animated: animated)
        cellBackgroundView.drawingContext.isHighlighted = highlighted
    }
}
