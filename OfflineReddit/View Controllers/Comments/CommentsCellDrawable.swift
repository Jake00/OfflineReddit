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
    var previousIndentation: Int
    var nextIndentation: Int
}

private let lightest: CGFloat = {
    var white: CGFloat = 1
    UIColor.offWhite.getWhite(&white, alpha: nil)
    return white
}()

extension CommentsCellDrawable {
    
    func color(forLevel level: Int) -> UIColor {
        return UIColor(white: lightest - (0.02 * CGFloat(level)), alpha: 1)
    }
    
    func backgroundRect(forLevel level: Int) -> CGRect {
        let indentation = CommentsCell.indentationWidth * CGFloat(level)
        return CGRect(x: indentation, y: 0, width: self.bounds.width, height: self.bounds.height)
    }
    
    func drawDecorations() {
        guard let context = UIGraphicsGetCurrentContext() else { return }
        let strokeWidth: CGFloat = 1
        context.setLineWidth(strokeWidth)
        
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
            context.setStrokeColor(color(forLevel: level + 3).cgColor)
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
            let rect = backgroundRect(forLevel: drawingContext.nextIndentation + 1)
            context.strokeLineSegments(between: [
                CGPoint(x: rect.minX, y: rect.maxY - strokeWidth / 2),
                CGPoint(x: rect.maxX, y: rect.maxY - strokeWidth / 2)])
        }
    }
}
