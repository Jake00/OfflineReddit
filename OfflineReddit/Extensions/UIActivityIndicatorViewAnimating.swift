//
//  UIActivityIndicatorViewAnimating.swift
//  OfflineReddit
//
//  Created by Jake Bellamy on 6/05/17.
//  Copyright © 2017 Jake Bellamy. All rights reserved.
//

import UIKit

extension UIActivityIndicatorView {
    
    func setAnimating(_ animating: Bool) {
        (animating ? startAnimating : stopAnimating)()
    }
}
