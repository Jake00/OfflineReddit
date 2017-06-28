//
//  URLLabelLinkControl.swift
//  OfflineReddit
//
//  Created by Jake Bellamy on 29/06/17.
//  Copyright © 2017 Jake Bellamy. All rights reserved.
//

import UIKit

class URLLabelLinkControl: UIControl {
    
    var link: NSTextCheckingResult?
    
    var lineRects: [CGRect] = [] {
        didSet {
            if lineRects.count < 2 {
                backgroundImageView.image = URLLabelLinkControl.singleRoundedRectImage
            } else {
                let rects = lineRects
                let bounds = self.bounds
                DispatchQueue.global().async {
                    let image = self.renderBackgroundImage(rects: rects, enclosingRect: bounds)
                    DispatchQueue.main.async {
                        self.backgroundImageView.image = image
                    }
                }
            }
        }
    }
    
    lazy var backgroundImageView: UIImageView = {
        let backgroundImageView = UIImageView(image: URLLabelLinkControl.singleRoundedRectImage)
        backgroundImageView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        backgroundImageView.frame = self.bounds
        backgroundImageView.isHidden = !self.isHighlighted
        self.addSubview(backgroundImageView)
        return backgroundImageView
    }()
    
    override var isHighlighted: Bool {
        didSet {
            backgroundImageView.isHidden = !isHighlighted
        }
    }
    
    private static var backgroundColor: UIColor {
        return UIColor(white: 0, alpha: 0.2)
    }
    
    private static let singleRoundedRectImage: UIImage? = {
        let cornerRadius: CGFloat = 4
        let size = CGSize(
            width: cornerRadius * 2 + 1,
            height: cornerRadius * 2 + 1)
        let path = CGPath(
            roundedRect: CGRect(origin: .zero, size: size),
            cornerWidth: cornerRadius,
            cornerHeight: cornerRadius,
            transform: nil)
        
        return render(size: size) { context in
            context.addPath(path)
            context.setFillColor(backgroundColor.cgColor)
            context.fillPath()
            }?.resizableImage(
                withCapInsets: UIEdgeInsets(
                    top: cornerRadius,
                    left: cornerRadius,
                    bottom: cornerRadius,
                    right: cornerRadius),
                resizingMode: .stretch)
    }()
    
    private func renderBackgroundImage(rects: [CGRect], enclosingRect: CGRect) -> UIImage? {
        let cornerRadius: CGFloat = 4
        let paths = rects.map { UIBezierPath(roundedRect: $0, cornerRadius: cornerRadius).cgPath }
        return render(size: enclosingRect.size) { context in
            paths.forEach(context.addPath)
            context.setFillColor(URLLabelLinkControl.backgroundColor.cgColor)
            context.fillPath(using: .winding)
        }
    }
}

private func render(size: CGSize, draw: (CGContext) -> Void) -> UIImage? {
    UIGraphicsBeginImageContextWithOptions(size, false, 0)
    defer { UIGraphicsEndImageContext() }
    guard let context = UIGraphicsGetCurrentContext() else { return nil }
    draw(context)
    return UIGraphicsGetImageFromCurrentImageContext()
}
