//
//  SubredditCell.swift
//  OfflineReddit
//
//  Created by Jake Bellamy on 21/03/17.
//  Copyright © 2017 Jake Bellamy. All rights reserved.
//

import UIKit

class SubredditCell: UITableViewCell, ReusableNibCell {
    
    var isChecked = false {
        didSet {
            accessoryType = isChecked ? .checkmark : .none
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
        selectedBackgroundView = UIView(backgroundColor: .selectedGray)
    }
}
