//
//  SeparatorView.swift
//  ThisOrThat
//
//  Created by Jake Bellamy on 11/03/17.
//  Copyright © 2017 Jake Bellamy. All rights reserved.
//

import UIKit

class SeparatorView: UIView {
    
    var isVertical: Bool {
        return translatesAutoresizingMaskIntoConstraints ? frame.height > frame.width : constraint(.height) != nil
    }
    
    func constraint(_ attribute: NSLayoutAttribute) -> NSLayoutConstraint? {
        return constraints.first { $0.firstAttribute == attribute && $0.secondAttribute == .notAnAttribute }
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .separator
        updateSize()
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
    
    override func awakeFromNib() {
        super.awakeFromNib()
        backgroundColor = .separator
        updateSize()
    }
    
    func updateSize() {
        let pixel = 1 / UIScreen.main.scale
        guard translatesAutoresizingMaskIntoConstraints else {
            (constraint(.height) ?? constraint(.width))?.constant = pixel
            return
        }
        if isVertical {
            frame.size.height = pixel
        } else {
            frame.size.width = pixel
        }
    }
}
