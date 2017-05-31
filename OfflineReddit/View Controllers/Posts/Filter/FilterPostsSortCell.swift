//
//  FilterPostsSortCell.swift
//  OfflineReddit
//
//  Created by Jake Bellamy on 27/05/17.
//  Copyright © 2017 Jake Bellamy. All rights reserved.
//

import UIKit

class FilterPostsSortCell: UITableViewCell, ReusableCell {
    
    let titleLabel = UILabel()
    let checkedImageView = UIImageView(image: #imageLiteral(resourceName: "checked"))
    private(set) var control: LabelSliderControl?
    
    var isChecked = false {
        didSet {
            checkedImageView.isHidden = !isChecked
            expandedConstraint?.isActive = isChecked
            control?.alpha = isChecked ? 1 : 0
        }
    }
    
    var canExpand = false {
        didSet { addControlIfNeeded() }
    }
    
    private var expandedConstraint: NSLayoutConstraint?
    
    func addControlIfNeeded() {
        guard canExpand else {
            self.control?.removeFromSuperview()
            self.control = nil
            self.expandedConstraint = nil
            return
        }
        
        let control = LabelSliderControl()
        self.control = control
        control.alpha = isChecked ? 1 : 0
        control.layoutMargins.top = 0
        control.translatesAutoresizingMaskIntoConstraints = false
        contentView.insertSubview(control, belowSubview: titleLabel)
        
        NSLayoutConstraint.activate([
            contentView.layoutMarginsGuide.leadingAnchor.constraint(equalTo: control.leadingAnchor),
            contentView.layoutMarginsGuide.trailingAnchor.constraint(equalTo: control.trailingAnchor),
            titleLabel.bottomAnchor.constraint(equalTo: control.topAnchor, constant: -4)
            ])
        
        expandedConstraint = contentView.layoutMarginsGuide.bottomAnchor.constraint(equalTo: control.bottomAnchor)
        expandedConstraint?.isActive = isChecked
    }
    
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
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        checkedImageView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(titleLabel)
        contentView.addSubview(checkedImageView)
        NSLayoutConstraint.activate([
            contentView.layoutMarginsGuide.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            checkedImageView.leadingAnchor.constraint(equalTo: titleLabel.trailingAnchor, constant: 8),
            checkedImageView.centerYAnchor.constraint(equalTo: titleLabel.centerYAnchor),
            contentView.layoutMarginsGuide.trailingAnchor.constraint(equalTo: checkedImageView.trailingAnchor),
            contentView.layoutMarginsGuide.topAnchor.constraint(equalTo: titleLabel.topAnchor),
            {
                let constraint = contentView.layoutMarginsGuide.bottomAnchor.constraint(equalTo: titleLabel.bottomAnchor)
                constraint.priority = 200
                return constraint
            }()])
    }
    
    // MARK: - View
    
    override func layoutSubviews() {
        super.layoutSubviews()
        UIView.performWithoutAnimation {
            contentView.layoutIfNeeded()
        }
    }
}
