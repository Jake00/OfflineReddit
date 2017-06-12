//
//  CommentsCell.swift
//  OfflineReddit
//
//  Created by Jake Bellamy on 20/03/17.
//  Copyright © 2017 Jake Bellamy. All rights reserved.
//

import UIKit

class CommentsCell: UITableViewCell, ReusableNibCell {
    
    @IBOutlet weak var topLabel: UILabel!
    @IBOutlet weak var bodyLabel: UILabel!
    @IBOutlet weak var bodyLabelLeading: NSLayoutConstraint!
    @IBOutlet var bodyLabelBottom: NSLayoutConstraint!
    
    static let indentationWidth: CGFloat = 15
    
    override var indentationLevel: Int {
        didSet {
            bodyLabelLeading.constant = CommentsCell.indentationWidth * CGFloat(indentationLevel)
            layoutMargins.left = bodyLabelLeading.constant + contentView.layoutMargins.left
            separatorInset.left = layoutMargins.left
        }
    }
    
    var isExpanded: Bool {
        get { return bodyLabelBottom.isActive }
        set {
            bodyLabelBottom.isActive = newValue
        }
    }
    
    var isExpanding: Bool = false
    
    override init(style: UITableViewCellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setup()
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        setup()
    }
    
    private func setup() {
        selectedBackgroundView = UIView(backgroundColor: .selectedGray)
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        if isExpanding {
            UIView.performWithoutAnimation {
                self.contentView.layoutIfNeeded()
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
