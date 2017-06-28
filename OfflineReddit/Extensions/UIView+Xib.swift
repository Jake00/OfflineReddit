//
//  UIView+Xib.swift
//  OfflineReddit
//
//  Created by Jake Bellamy on 6/06/17.
//  Copyright © 2017 Jake Bellamy. All rights reserved.
//

import UIKit

extension UIView {
    
    class func instantiateFromNib(named name: String? = nil, owner: Any? = nil) -> Self {
        let name = name ?? String(describing: self)
        guard let view = Bundle.main.loadNibNamed(name, owner: owner, options: nil)?.first else {
            fatalError("Unable to instantiate nib named \(name)")
        }
        
        // Workaround inability to cast directly to `Self`
        func cast<T>(_ object: Any) -> T {
            return object as? T ?? {
                fatalError("Nib did not instantate as \(T.self), instead it was \(type(of: object))")
                }()
        }
        return cast(view)
    }
    
    convenience init(backgroundColor: UIColor) {
        self.init(frame: .zero)
        self.backgroundColor = backgroundColor
    }
    
    func insertSubview(_ subview: UIView, belowChildSubview siblingSubview: UIView) {
        if siblingSubview.superview == self {
            insertSubview(subview, belowSubview: siblingSubview)
        } else if let superview = siblingSubview.superview {
            insertSubview(subview, belowChildSubview: superview)
        }
    }
}
