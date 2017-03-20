//
//  MoreCell.swift
//  OfflineReddit
//
//  Created by Jake Bellamy on 20/03/17.
//  Copyright © 2017 Jake Bellamy. All rights reserved.
//

import UIKit

class MoreCell: UITableViewCell {
    
    @IBOutlet var titleLabel: UILabel!
    @IBOutlet var activityIndicator: UIActivityIndicatorView!
    @IBOutlet weak var containerLeading: NSLayoutConstraint?
    @IBOutlet weak var container: UIView?
    
    override var indentationLevel: Int {
        didSet {
            let indentation = CommentCell.indentationWidth * CGFloat(indentationLevel)
            containerLeading?.constant = indentation
            layoutMargins.left = indentation + contentView.layoutMargins.left
            separatorInset.left = layoutMargins.left
        }
    }
    
    override init(style: UITableViewCellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        backgroundColor = UIColor(white: 0.95, alpha: 1)
        titleLabel = UILabel()
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.font = .systemFont(ofSize: 15)
        titleLabel.textAlignment = .center
        titleLabel.textColor = UIColor(white: 0.1, alpha: 1)
        titleLabel.numberOfLines = 0
        activityIndicator = UIActivityIndicatorView(activityIndicatorStyle: .gray)
        activityIndicator.translatesAutoresizingMaskIntoConstraints = false
        activityIndicator.hidesWhenStopped = true
        
        contentView.addSubview(titleLabel)
        contentView.addSubview(activityIndicator)
        
        NSLayoutConstraint.activate([
            contentView.layoutMarginsGuide.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            contentView.layoutMarginsGuide.trailingAnchor.constraint(equalTo: titleLabel.trailingAnchor),
            contentView.layoutMarginsGuide.topAnchor.constraint(equalTo: titleLabel.topAnchor),
            contentView.layoutMarginsGuide.bottomAnchor.constraint(equalTo: titleLabel.bottomAnchor),
            contentView.centerXAnchor.constraint(equalTo: activityIndicator.centerXAnchor),
            contentView.centerYAnchor.constraint(equalTo: activityIndicator.centerYAnchor)
            ])
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
    
    override func setHighlighted(_ highlighted: Bool, animated: Bool) {
        super.setHighlighted(highlighted, animated: animated)
        container?.backgroundColor = .selectedGray
    }
    
    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)
        container?.backgroundColor = .selectedGray
    }
}
