//
//  URLTextView.swift
//  OfflineReddit
//
//  Created by Jake Bellamy on 19/06/17.
//  Copyright © 2017 Jake Bellamy. All rights reserved.
//

import UIKit

class URLTextView: UITextView {
    
    var blockQuoteRanges: [NSRange] = []
    
    // Disable double tap selecting link text
    override func addGestureRecognizer(_ gestureRecognizer: UIGestureRecognizer) {
        if (gestureRecognizer as? UITapGestureRecognizer)?.numberOfTapsRequired == 2 {
            return
        }
        super.addGestureRecognizer(gestureRecognizer)
    }
    
    // Disallow interaction unless `point` contains a link (allow superview to capture touches)
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        guard isUserInteractionEnabled, isSelectable, textStorage.length > 0,
            self.point(inside: point, with: event)
            else { return nil }
        
        var location = point
        location.x -= textContainerInset.left
        location.y -= textContainerInset.top
        
        let characterIndex = layoutManager.characterIndex(
            for: location,
            in: textContainer,
            fractionOfDistanceBetweenInsertionPoints: nil)
        
        let isLink = textStorage.attribute(
            NSLinkAttributeName,
            at: characterIndex, effectiveRange: nil
            ) != nil
        
        return isLink ? self : nil
    }
    
    override var intrinsicContentSize: CGSize {
        return attributedText.length == 0 ? .zero : super.intrinsicContentSize
    }
    
    override func draw(_ rect: CGRect) {
        guard !blockQuoteRanges.isEmpty,
            let context = UIGraphicsGetCurrentContext()
            else { return }
        context.setStrokeColor(UIColor.lightMidGray.cgColor)
        let lineWidth: CGFloat = 2.5
        context.setLineWidth(lineWidth)
        let x = lineWidth / 2
        for range in blockQuoteRanges {
            let glyphRange = layoutManager.glyphRange(forCharacterRange: range, actualCharacterRange: nil)
            let rect = layoutManager.boundingRect(forGlyphRange: glyphRange, in: textContainer).insetBy(dx: 0, dy: 3.5)
            let start = CGPoint(x: x, y: rect.minY)
            let end = CGPoint(x: x, y: rect.maxY)
            context.strokeLineSegments(between: [start, end])
        }
    }
    
    // MARK: - Init
    
    override init(frame: CGRect, textContainer: NSTextContainer?) {
        super.init(frame: frame, textContainer: textContainer)
        setup()
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        setup()
    }
    
    private func setup() {
        isSelectable = true
        textContainerInset = .zero
        textContainer.lineFragmentPadding = 0
    }
}
