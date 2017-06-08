//
//  UIFont+Weight.swift
//  OfflineReddit
//
//  Created by Jake Bellamy on 8/06/17.
//  Copyright © 2017 Jake Bellamy. All rights reserved.
//

import UIKit

extension UIFont {
    
    enum Weight {
        case ultraLight
        case thin
        case light
        case regular
        case medium
        case semibold
        case bold
        case heavy
        case black
        
        var value: CGFloat {
            switch self {
            case .ultraLight: return UIFontWeightUltraLight
            case .thin:       return UIFontWeightThin
            case .light:      return UIFontWeightLight
            case .regular:    return UIFontWeightRegular
            case .medium:     return UIFontWeightMedium
            case .semibold:   return UIFontWeightSemibold
            case .bold:       return UIFontWeightBold
            case .heavy:      return UIFontWeightHeavy
            case .black:      return UIFontWeightBlack
            }
        }
    }
    
    class func preferredFont(forTextStyle style: UIFontTextStyle, weight: Weight) -> UIFont {
        let descriptor = UIFontDescriptor.preferredFontDescriptor(withTextStyle: style)
            .addingAttributes([UIFontWeightTrait: weight.value])
        return UIFont(descriptor: descriptor, size: descriptor.pointSize)
    }
}
