//
//  MarginTextField.swift
//  ThisOrThat
//
//  Created by Jake Bellamy on 12/03/17.
//  Copyright © 2017 Jake Bellamy. All rights reserved.
//

import UIKit

class MarginTextField: UITextField {
    
    @IBInspectable var leadingMargin: CGFloat = .nan
    @IBInspectable var trailingMargin: CGFloat = .nan
    
    private var _leadingMargin: CGFloat {
        return leadingMargin.isNaN ? superview?.layoutMargins.left ?? 0 : leadingMargin
    }
    
    private var _trailingMargin: CGFloat {
        return trailingMargin.isNaN ? superview?.layoutMargins.right ?? 0 : trailingMargin
    }
    
    override func placeholderRect(forBounds bounds: CGRect) -> CGRect {
        return textRect(bounds, super.placeholderRect(forBounds: bounds))
    }
    
    override func textRect(forBounds bounds: CGRect) -> CGRect {
        return textRect(bounds, super.textRect(forBounds: bounds))
    }
    
    override func editingRect(forBounds bounds: CGRect) -> CGRect {
        return textRect(bounds, super.editingRect(forBounds: bounds))
    }
    
    override func clearButtonRect(forBounds bounds: CGRect) -> CGRect {
        var rect = super.clearButtonRect(forBounds: bounds)
        rect.origin.x = bounds.width - rect.width - _trailingMargin
        return rect
    }
    
    override func rightViewRect(forBounds bounds: CGRect) -> CGRect {
        var rect = super.rightViewRect(forBounds: bounds)
        rect.origin.x = bounds.width - rect.width - _trailingMargin
        return rect
    }
    
    override func leftViewRect(forBounds bounds: CGRect) -> CGRect {
        var rect = super.leftViewRect(forBounds: bounds)
        rect.origin.x = _leadingMargin
        return rect
    }
    
    private func textRect(_ bounds: CGRect, _ rect: CGRect) -> CGRect {
        var rect = rect
        rect.origin.x = leftView.map { $0.frame.maxX + _leadingMargin / 2 } ?? _leadingMargin
        rect.size.width = bounds.width - rect.origin.x
        rect.size.width -= (rightView.map { bounds.width - $0.frame.minX + _trailingMargin / 2 } ?? _trailingMargin)
        return rect
    }
}
