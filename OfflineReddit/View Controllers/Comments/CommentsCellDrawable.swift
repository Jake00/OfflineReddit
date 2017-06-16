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
    var drawingContext: CommentsCellDrawingContext { get set }
    var indentationLevel: Int { get set }
    var bounds: CGRect { get }
    var isHighlighted: Bool { get }
}

struct CommentsCellDrawingContext {
    let indentationWidth: CGFloat = 10
    var previousIndentation: Int
    var nextIndentation: Int
    
    func bottomIndentationMargin(forLevel level: Int) -> CGFloat {
        return CGFloat(max(0, level - nextIndentation - 1)) * (indentationWidth / 2)
    }
}

private let lightest: CGFloat = {
    var white: CGFloat = 1
    UIColor.offWhite.getWhite(&white, alpha: nil)
    return white
}()

extension CommentsCellDrawable {
    
    var bottomIndentationMargin: CGFloat {
        return drawingContext.bottomIndentationMargin(forLevel: indentationLevel)
    }
    
    func color(forLevel level: Int) -> UIColor {
        return UIColor(white: lightest - (0.02 * CGFloat(level)), alpha: 1)
    }
    
    func backgroundRect(forLevel level: Int) -> CGRect {
        let indentation = drawingContext.indentationWidth * CGFloat(level)
        return CGRect(x: indentation, y: 0, width: self.bounds.width, height: self.bounds.height - drawingContext.bottomIndentationMargin(forLevel: level))
    }
    
    func drawDecorations() {
        guard let context = UIGraphicsGetCurrentContext() else { return }
        let strokeWidth: CGFloat = pixel
        context.setLineWidth(strokeWidth)
        context.setAllowsAntialiasing(false)
        
        guard indentationLevel > 0 else {
            if isHighlighted {
                context.setFillColor(color(forLevel: 2).cgColor)
                context.fill(bounds)
            }
            return
        }
        
        for level in 1..<indentationLevel + 1 {
            let rect = backgroundRect(forLevel: level)
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
        if drawingContext.previousIndentation < indentationLevel {
            let rect = backgroundRect(forLevel: drawingContext.previousIndentation + 1)
            context.strokeLineSegments(between: [
                CGPoint(x: rect.minX, y: rect.minY + strokeWidth / 2),
                CGPoint(x: rect.maxX, y: rect.minY + strokeWidth / 2)])
        }
        if drawingContext.nextIndentation < indentationLevel {
            for level in drawingContext.nextIndentation..<indentationLevel {
                let rect = backgroundRect(forLevel: level + 1)
                context.strokeLineSegments(between: [
                    CGPoint(x: rect.minX, y: rect.maxY - strokeWidth / 2),
                    CGPoint(x: rect.maxX, y: rect.maxY - strokeWidth / 2)])
            }
        }
    }
}
