//
//  URLLabel.swift
//  OfflineReddit
//
//  Created by Jake Bellamy on 24/06/17.
//  Copyright © 2017 Jake Bellamy. All rights reserved.
//

import UIKit

protocol URLLabelDelegate: class {
    func urlLabel(_ urlLabel: URLLabel, didSelectLinkWith url: URL)
}

class URLLabel: UILabel {
    
    var blockQuoteRanges: [NSRange] = []
    
    var textRectCache: TextRectCache?
    
    weak var delegate: URLLabelDelegate?
    
    var linkControlsSuperview: UIView? {
        didSet {
            if let linkControlsSuperview = linkControlsSuperview, superview != nil {
                linkControls.forEach { linkControlsSuperview.insertSubview($0, belowChildSubview: self) }
                setNeedsLayout()
            } else {
                linkControls.forEach { $0.removeFromSuperview() }
            }
        }
    }
    
    // MARK: - Text layout
    
    lazy var textStorage: NSTextStorage = {
        let textStorage = NSTextStorage()
        textStorage.addLayoutManager(self.layoutManager)
        return textStorage
    }()
    
    lazy var layoutManager: NSLayoutManager = {
        let layoutManager = URLLabelLayoutManager()
        layoutManager.addTextContainer(self.textContainer)
        return layoutManager
    }()
    
    lazy var textContainer: NSTextContainer = {
        let textContainer = NSTextContainer()
        textContainer.lineFragmentPadding = 0
        textContainer.maximumNumberOfLines = self.numberOfLines
        textContainer.lineBreakMode = self.lineBreakMode
        textContainer.size = self.bounds.size
        return textContainer
    }()
    
    // MARK: - Attributed text
    
    var generatedAttributedText: NSAttributedString {
        return NSAttributedString(string: text ?? "", attributes: [
            NSFontAttributeName: font,
            NSForegroundColorAttributeName: textColor
            ])
    }
    
    private var _attributedText: NSAttributedString? {
        get { return textStorage }
        set {
            textStorage.setAttributedString(newValue ?? NSAttributedString(string: ""))
        }
    }
    
    override var attributedText: NSAttributedString? {
        get { return _attributedText }
        set {
            links = []
            guard let newValue = newValue else {
                _attributedText = nil; return
            }
            let text = addLinkAttributes(to: newValue)
            _attributedText = text
            checkForLinks(in: text)
        }
    }
    
    // MARK: - UILabel
    
    override func layoutSubviews() {
        super.layoutSubviews()
        if textContainer.size != bounds.size {
            textContainer.size = bounds.size
        }
        guard superview != nil else { return }
        
        while links.count > linkControls.count {
            let control = URLLabelLinkControl()
            control.addTarget(self, action: #selector(linkSelected(_:)), for: .touchUpInside)
            linkControls.append(control)
            if let linkControlsSuperview = linkControlsSuperview {
                
                linkControlsSuperview.insertSubview(control, belowChildSubview: self)
            }
        }
        while links.count < linkControls.count {
            linkControls.removeLast().removeFromSuperview()
        }
        for (linkControl, link) in zip(linkControls, links) {
            linkControl.url = link.url
            linkControl.frame = linkControlsSuperview?
                .convert(subtextRect(range: link.range), from: self)
                .insetBy(dx: -4, dy: -2) ?? .zero
        }
    }
    
    override func didMoveToSuperview() {
        if superview == nil {
            linkControls.forEach { $0.removeFromSuperview() }
        }
    }
    
    var isIntrinsicContentSizeEnabled = true
    
    override var intrinsicContentSize: CGSize {
        return isIntrinsicContentSizeEnabled ? super.intrinsicContentSize : .zero
    }
    
    override func textRect(forBounds bounds: CGRect, limitedToNumberOfLines numberOfLines: Int) -> CGRect {
        guard let text = attributedText?.string, !text.isEmpty else {
            var bounds = bounds
            bounds.size.height = 0
            return bounds
        }
        let textRect = TextRectCache.TextRect(text: text, bounds: bounds, numberOfLines: numberOfLines)
        if let rect = textRectCache?.stored[textRect] {
            return rect
        }
        let previousSize = textContainer.size
        let previousNumberOfLines = textContainer.maximumNumberOfLines
        
        textContainer.size = bounds.size
        textContainer.maximumNumberOfLines = numberOfLines
        defer {
            textContainer.size = previousSize
            textContainer.maximumNumberOfLines = previousNumberOfLines
        }
        
        let glyphRange = layoutManager.glyphRange(for: textContainer)
        var textBounds = layoutManager.boundingRect(forGlyphRange: glyphRange, in: textContainer)
        textBounds.origin = bounds.origin
        textBounds.size.width = textBounds.size.width.rounded(.up)
        textBounds.size.height = textBounds.size.height.rounded(.up)
        textRectCache?.stored[textRect] = textBounds
        return textBounds
    }
    
    func subtextRect(range: NSRange) -> CGRect {
        var glyphRange = NSRange()
        layoutManager.characterRange(forGlyphRange: range, actualGlyphRange: &glyphRange)
        return layoutManager.boundingRect(forGlyphRange: glyphRange, in: textContainer)
    }
    
    override func drawText(in rect: CGRect) {
        let glyphRange = layoutManager.glyphRange(for: textContainer)
        layoutManager.drawGlyphs(forGlyphRange: glyphRange, at: .zero)
        
        guard !blockQuoteRanges.isEmpty,
            let context = UIGraphicsGetCurrentContext()
            else { return }
        context.setStrokeColor(UIColor.lightMidGray.cgColor)
        let lineWidth: CGFloat = 2.5
        context.setLineWidth(lineWidth)
        let x = lineWidth / 2
        for range in blockQuoteRanges {
            let rect = subtextRect(range: range).insetBy(dx: 0, dy: 3)
            let start = CGPoint(x: x, y: rect.minY)
            let end = CGPoint(x: x, y: rect.maxY)
            context.strokeLineSegments(between: [start, end])
        }
    }
    
    // MARK: - Link checking
    
    var linkAttributes: [String: Any] = [:]
    
    private(set) var links: [NSTextCheckingResult] = []
    private(set) var linkControls: [URLLabelLinkControl] = []
    
    static let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue)
    
    func checkForLinks(in text: NSAttributedString) {
        DispatchQueue.global().async { [weak self] in
            let range = NSRange(location: 0, length: text.length)
            let string = text.string
            guard let matches = URLLabel.detector?.matches(in: string, options: [], range: range),
                !matches.isEmpty
                else { return }
            DispatchQueue.main.async {
                if self?.attributedText?.string == string {
                    self?.addLinks(from: matches, in: text)
                }
            }
        }
    }
    
    func addLinks(from results: [NSTextCheckingResult], in text: NSAttributedString) {
        guard !results.isEmpty else { return }
        let text = text.mutableCopy() as! NSMutableAttributedString
        var attributes = linkAttributes
        for result in results {
            guard let url = result.url else { continue }
            attributes[NSLinkAttributeName] = url
            text.addAttributes(attributes, range: result.range)
        }
        links += results
        _attributedText = text
    }
    
    func addLinkAttributes(to text: NSAttributedString) -> NSAttributedString {
        let text = text.mutableCopy() as! NSMutableAttributedString
        let range = NSRange(location: 0, length: text.length)
        text.enumerateAttribute(NSLinkAttributeName, in: range, options: []) { value, range, _ in
            guard let url = (value as? String).flatMap(URL.init(string:)) ?? value as? URL
                else { return }
            text.addAttributes(linkAttributes, range: range)
            links.append(NSTextCheckingResult.linkCheckingResult(range: range, url: url))
        }
        return text
    }
    
    // MARK: - Link selection
    
    func linkSelected(_ sender: URLLabelLinkControl) {
        guard let url = sender.url else { return }
        delegate?.urlLabel(self, didSelectLinkWith: url)
    }
}

class URLLabelLinkControl: UIControl {
    
    var url: URL?
    
    lazy var backgroundImageView: UIImageView = {
        let backgroundImageView = UIImageView(image: URLLabelLinkControl.backgroundImage)
        backgroundImageView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        backgroundImageView.frame = self.bounds
        self.addSubview(backgroundImageView)
        return backgroundImageView
    }()
    
    override var isHighlighted: Bool {
        didSet {
            backgroundImageView.isHidden = !isHighlighted
        }
    }
    
    private static let backgroundImage: UIImage? = {
        let cornerRadius: CGFloat = 4
        let size = CGSize(width: cornerRadius * 2 + 1, height: cornerRadius * 2 + 1)
        UIGraphicsBeginImageContextWithOptions(size, false, 0)
        defer { UIGraphicsEndImageContext() }
        guard let context = UIGraphicsGetCurrentContext() else { return nil }
        let path = CGPath(roundedRect: CGRect(origin: .zero, size: size), cornerWidth: cornerRadius, cornerHeight: cornerRadius, transform: nil)
        context.addPath(path)
        context.setFillColor(UIColor(white: 0, alpha: 0.2).cgColor)
        context.fillPath()
        return UIGraphicsGetImageFromCurrentImageContext()?.resizableImage(
            withCapInsets: UIEdgeInsets(top: cornerRadius, left: cornerRadius, bottom: cornerRadius, right: cornerRadius),
            resizingMode: .stretch)
    }()
}

class URLLabelLayoutManager: NSLayoutManager {
    
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

private extension UIView {
    
    func insertSubview(_ subview: UIView, belowChildSubview siblingSubview: UIView) {
        if siblingSubview.superview == self {
            insertSubview(subview, belowSubview: siblingSubview)
        } else if let superview = siblingSubview.superview {
            insertSubview(subview, belowChildSubview: superview)
        }
    }
}

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
