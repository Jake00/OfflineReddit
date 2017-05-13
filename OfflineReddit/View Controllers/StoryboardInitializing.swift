//
//  StoryboardInitializing.swift
//  OfflineReddit
//
//  Created by Jake Bellamy on 13/05/17.
//  Copyright © 2017 Jake Bellamy. All rights reserved.
//

import UIKit

protocol StoryboardInitializable {
    static var storyboardIdentifier: String { get }
}

extension StoryboardInitializable where Self: UIViewController {
    
    static func instantiateFromStoryboard() -> Self {
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        let viewController = storyboard.instantiateViewController(withIdentifier: storyboardIdentifier)
        return viewController as? Self ?? {
            fatalError("View controller '\(viewController)' with storyboard identifier '\(storyboardIdentifier)' did not instantiate as its correct type. Expected: \(type(of: self)), actual: \(type(of: viewController))")
        }()
    }
}
