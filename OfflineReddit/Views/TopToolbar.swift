//
//  TopToolbar.swift
//  OfflineReddit
//
//  Created by Jake Bellamy on 4/06/17.
//  Copyright © 2017 Jake Bellamy. All rights reserved.
//

import UIKit

class TopToolbar: UIToolbar, UIToolbarDelegate {
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        self.delegate = self
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        self.delegate = self
    }
    
    func position(for bar: UIBarPositioning) -> UIBarPosition {
        return .top
    }
}
