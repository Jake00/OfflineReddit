//
//  TextRectCache.swift
//  OfflineReddit
//
//  Created by Jake Bellamy on 29/06/17.
//  Copyright © 2017 Jake Bellamy. All rights reserved.
//

import UIKit

final class TextRectCache {
    
    struct TextRect: Hashable {
        let text: String
        let bounds: CGRect
        let numberOfLines: Int
        
        static func == (lhs: TextRect, rhs: TextRect) -> Bool {
            return lhs.text == rhs.text
                && lhs.bounds == rhs.bounds
                && lhs.numberOfLines == rhs.numberOfLines
        }
        
        var hashValue: Int {
            return text.hashValue
                &+ bounds.width.hashValue
                &+ bounds.height.hashValue
                &+ numberOfLines
        }
    }
    
    var stored: [TextRect: CGRect] = [:]
}
