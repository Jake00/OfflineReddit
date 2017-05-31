//
//  FilterPostsSegmentedControlCell.swift
//  OfflineReddit
//
//  Created by Jake Bellamy on 27/05/17.
//  Copyright © 2017 Jake Bellamy. All rights reserved.
//

import UIKit

class FilterPostsSegmentedControlCell: UITableViewCell, ReusableCell {
    
    let control = UISegmentedControl()
    
    // MARK: - Init
    
    override init(style: UITableViewCellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setup()
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        setup()
    }
    
    private func setup() {
        control.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(control)
        NSLayoutConstraint.activate([
            contentView.layoutMarginsGuide.leadingAnchor.constraint(equalTo: control.leadingAnchor),
            contentView.layoutMarginsGuide.trailingAnchor.constraint(equalTo: control.trailingAnchor),
            contentView.layoutMarginsGuide.topAnchor.constraint(equalTo: control.topAnchor),
            contentView.layoutMarginsGuide.bottomAnchor.constraint(equalTo: control.bottomAnchor)
            ])
    }
}
