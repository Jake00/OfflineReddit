//
//  UILabel+SubtextFrame.swift
//  OfflineReddit
//
//  Created by Jake Bellamy on 16/06/17.
//  Copyright © 2017 Jake Bellamy. All rights reserved.
//

import UIKit

extension UILabel {
    
    func frame(forSubtextRange range: NSRange) -> CGRect {
        let attributedText = self.attributedText
            ?? NSAttributedString(string: text ?? "", attributes: [NSFontAttributeName: font])
        
        let container = NSTextContainer(size: bounds.size)
        let manager = NSLayoutManager()
        manager.addTextContainer(container)
        let storage = NSTextStorage(attributedString: attributedText)
        storage.addLayoutManager(manager)
        
        let glyphRange = manager.glyphRange(forCharacterRange: range, actualCharacterRange: nil)
        return manager.boundingRect(forGlyphRange: glyphRange, in: container)
    }
}
