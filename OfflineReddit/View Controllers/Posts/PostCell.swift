//
//  PostCell.swift
//  OfflineReddit
//
//  Created by Jake Bellamy on 21/03/17.
//  Copyright © 2017 Jake Bellamy. All rights reserved.
//

import UIKit

class PostCell: UITableViewCell, ReusableNibCell {
    
    @IBOutlet weak var topLabel: UILabel!
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var bottomLabel: UILabel!
    @IBOutlet weak var checkedImageView: UIImageView!
    @IBOutlet weak var activityIndicator: UIActivityIndicatorView!
    @IBOutlet weak var container: UIView!
    @IBOutlet weak var containerLeading: NSLayoutConstraint!
    @IBOutlet weak var offlineImageView: UIImageView!
    
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
}
