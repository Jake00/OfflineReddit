//
//  URLLabelLayoutManager.swift
//  OfflineReddit
//
//  Created by Jake Bellamy on 29/06/17.
//  Copyright © 2017 Jake Bellamy. All rights reserved.
//

import UIKit

class URLLabelLayoutManager: NSLayoutManager {
    
    // swiftlint:disable:next function_parameter_count
    override func showCGGlyphs(
        _ glyphs: UnsafePointer<CGGlyph>,
        positions: UnsafePointer<CGPoint>,
        count glyphCount: Int,
        font: UIFont,
        matrix textMatrix: CGAffineTransform,
        attributes: [String : Any] = [:],
        in graphicsContext: CGContext) {
        
        if let color = attributes[NSForegroundColorAttributeName] as? UIColor {
            graphicsContext.setFillColor(color.cgColor)
        }
        super.showCGGlyphs(
            glyphs,
            positions: positions,
            count: glyphCount,
            font: font,
            matrix: textMatrix,
            attributes: attributes,
            in: graphicsContext)
    }
}
