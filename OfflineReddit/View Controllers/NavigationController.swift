//
//  NavigationController.swift
//  OfflineReddit
//
//  Created by Jake Bellamy on 21/03/17.
//  Copyright © 2017 Jake Bellamy. All rights reserved.
//

import UIKit

class NavigationController: UINavigationController {
    
    lazy var progressView: UIProgressView = {
        let progressView = UIProgressView(progressViewStyle: .bar)
        progressView.progressTintColor = self.view.tintColor
        progressView.trackTintColor = .clear
        progressView.frame = CGRect(
            x: 0,
            y: self.navigationBar.frame.height - progressView.frame.height,
            width: self.navigationBar.frame.width,
            height: progressView.frame.height
        )
        self.navigationBar.addSubview(progressView)
        progressView.setProgress(0, animated: false)
        progressView.layoutIfNeeded()
        progressView.isHidden = true
        return progressView
    }()
    
}
