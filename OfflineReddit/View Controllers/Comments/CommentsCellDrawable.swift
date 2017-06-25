//
//  CommentsCellDrawable.swift
//  OfflineReddit
//
//  Created by Jake Bellamy on 12/06/17.
//  Copyright © 2017 Jake Bellamy. All rights reserved.
//

import UIKit

// CommentsCell and MoreCommentsCell conform to this for drawing the decorations for their indentation level.
protocol CommentsCellDrawable: class {
    var cellBackgroundView: CommentsCellBackgroundView { get }
}

struct CommentsCellDrawingContext: Hashable {
    var indentationLevel: Int
    var previousIndentation: Int
    var nextIndentation: Int
    var isHighlighted: Bool
    let indentationWidth: CGFloat = 10
    
    func bottomIndentationMargin(forLevel level: Int) -> CGFloat {
        return CGFloat(max(0, level - nextIndentation - 1)) * (indentationWidth / 2)
    }
    
    var bottomIndentationMargin: CGFloat {
        return bottomIndentationMargin(forLevel: indentationLevel)
    }
    
    var leftIndentationMargin: CGFloat {
        return indentationWidth * CGFloat(indentationLevel)
    }
    
    func color(forLevel level: Int) -> UIColor {
        return UIColor(white: lightest - (0.02 * CGFloat(level)), alpha: 1)
    }
    
    func backgroundRect(forLevel level: Int, size: CGSize) -> CGRect {
        let indentation = indentationWidth * CGFloat(level)
        return CGRect(x: indentation, y: 0, width: size.width, height: size.height - bottomIndentationMargin(forLevel: level))
    }
    
    static func == (lhs: CommentsCellDrawingContext, rhs: CommentsCellDrawingContext) -> Bool {
        return lhs.indentationLevel == rhs.indentationLevel
            && lhs.previousIndentation == rhs.previousIndentation
            && lhs.nextIndentation == rhs.nextIndentation
            && lhs.isHighlighted == rhs.isHighlighted
    }
    
    var hashValue: Int {
        return indentationLevel
            &+ (previousIndentation &* 100)
            &+ (nextIndentation &* 10000)
            &+ (isHighlighted ? 10 : 9)
    }
    
    static var cached: [CommentsCellDrawingContext: UIImage] = [:]
    
    func backgroundImage() -> UIImage? {
        if let image = CommentsCellDrawingContext.cached[self] {
            return image
        } else if let image = render() {
            CommentsCellDrawingContext.cached[self] = image
            return image
        }
        return nil
    }
    
    private func render() -> UIImage? {
        let size = CGSize(width: leftIndentationMargin + 4 * pixel, height: bottomIndentationMargin + 3 * pixel)
        let capInsets = UIEdgeInsets(top: pixel, left: size.width - pixel, bottom: size.height - pixel, right: pixel)
        let bounds = CGRect(origin: .zero, size: size)
        UIGraphicsBeginImageContextWithOptions(size, true, 0)
        defer { UIGraphicsEndImageContext() }
        guard let context = UIGraphicsGetCurrentContext() else { return nil }
        let strokeWidth: CGFloat = pixel
        context.setLineWidth(strokeWidth)
        context.setAllowsAntialiasing(false)
        
        guard indentationLevel > 0 else {
            context.setFillColor(color(forLevel: isHighlighted ? 2 : 0).cgColor)
            context.fill(bounds)
            return UIGraphicsGetImageFromCurrentImageContext()?
                .resizableImage(withCapInsets: capInsets, resizingMode: .stretch)
        }
        context.setFillColor(color(forLevel: 0).cgColor)
        context.fill(bounds)
        
        for level in 1..<indentationLevel + 1 {
            let rect = backgroundRect(forLevel: level, size: size)
            var colorLevel = level
            if isHighlighted && level == indentationLevel {
                colorLevel += 2
            }
            context.setFillColor(color(forLevel: colorLevel).cgColor)
            context.fill(rect)
            context.setStrokeColor(color(forLevel: level + 7).cgColor)
            context.strokeLineSegments(between: [
                rect.origin,
                CGPoint(x: rect.minX, y: rect.maxY)])
        }
        if previousIndentation < indentationLevel {
            let rect = backgroundRect(forLevel: previousIndentation + 1, size: size)
            context.strokeLineSegments(between: [
                CGPoint(x: rect.minX, y: rect.minY + strokeWidth / 2),
                CGPoint(x: rect.maxX, y: rect.minY + strokeWidth / 2)])
        }
        if nextIndentation < indentationLevel {
            for level in nextIndentation..<indentationLevel {
                let rect = backgroundRect(forLevel: level + 1, size: size)
                context.strokeLineSegments(between: [
                    CGPoint(x: rect.minX, y: rect.maxY - strokeWidth / 2),
                    CGPoint(x: rect.maxX, y: rect.maxY - strokeWidth / 2)])
            }
        }
        return UIGraphicsGetImageFromCurrentImageContext()?
            .resizableImage(withCapInsets: capInsets, resizingMode: .stretch)
    }
}

private let lightest: CGFloat = {
    var white: CGFloat = 1
    UIColor.offWhite.getWhite(&white, alpha: nil)
    return white
}()

class CommentsCellBackgroundView: UIImageView {
    
    var drawingContext = CommentsCellDrawingContext(indentationLevel: 0, previousIndentation: 0, nextIndentation: 0, isHighlighted: false) {
        didSet {
            if oldValue != drawingContext {
                (superview as? UITableViewCell)?.indentationLevel = drawingContext.indentationLevel
                image = drawingContext.backgroundImage()
            }
        }
    }
}
