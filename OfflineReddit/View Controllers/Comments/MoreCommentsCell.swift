//
//  MoreCommentsCell.swift
//  OfflineReddit
//
//  Created by Jake Bellamy on 19/05/17.
//  Copyright © 2017 Jake Bellamy. All rights reserved.
//

import UIKit

class MoreCommentsCell: UITableViewCell, ReusableNibCell {
    
    @IBOutlet var titleLabel: UILabel!
    @IBOutlet var activityIndicator: UIActivityIndicatorView!
    @IBOutlet weak var containerLeading: NSLayoutConstraint!
    @IBOutlet weak var container: UIView!
    
    override var indentationLevel: Int {
        didSet {
            let indentation = CommentsCell.indentationWidth * CGFloat(indentationLevel)
            containerLeading.constant = indentation
            layoutMargins.left = indentation + contentView.layoutMargins.left
            separatorInset.left = layoutMargins.left
        }
    }
    
    override init(style: UITableViewCellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setup()
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        setup()
    }
    
    private func setup() {
        let selectedBackgroundView = UIView()
        selectedBackgroundView.backgroundColor = .selectedGray
        self.selectedBackgroundView = selectedBackgroundView
    }
    
    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)
        container.backgroundColor = .selectedGray
    }
}
