//
//  UISegmentedControl+Items.swift
//  OfflineReddit
//
//  Created by Jake Bellamy on 27/05/17.
//  Copyright © 2017 Jake Bellamy. All rights reserved.
//

import UIKit

extension UISegmentedControl {
    
    var items: [String] {
        get {
            return (0..<numberOfSegments).flatMap { titleForSegment(at: $0) }
        }
        set {
            while numberOfSegments > newValue.count {
                removeSegment(at: numberOfSegments - 1, animated: false)
            }
            for (index, title) in newValue.enumerated() {
                if index >= numberOfSegments {
                    insertSegment(withTitle: title, at: index, animated: false)
                } else {
                    setTitle(title, forSegmentAt: index)
                }
            }
        }
    }
}
