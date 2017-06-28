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
    
    func setNavigationBarHidden(
        _ hidden: Bool,
        transitioningWith view: UIView,
        additionalAnimations: @escaping () -> Void,
        completion: @escaping () -> Void
        ) {
        
        let navigationBarSubviews: [UIView] = navigationBar.subviews.filter {
            $0 != navigationBar.subviews.first && !$0.isHidden && $0.alpha > 0
        }
        
        let snapshot = makeSnapshot(of: view, isHidden: hidden)
        let bar = self.navigationBar as? NavigationBar
        let duration: TimeInterval = 0.3
        let thirdDuration = duration / 3
        
        if hidden {
            UIView.animate(withDuration: duration) {
                bar?.height = view.frame.height - UIApplication.shared.statusBarFrame.height
                bar?.sizeToFit()
                additionalAnimations()
            }
        } else {
            bar?.height = view.frame.height - UIApplication.shared.statusBarFrame.height
            bar?.sizeToFit()
            setNavigationBarHidden(hidden, animated: false)
            snapshot.map(self.view.bringSubview(toFront:))
            navigationBarSubviews.forEach { $0.alpha = 0 }
            UIView.animate(withDuration: duration) {
                bar?.height = nil
                bar?.sizeToFit()
                additionalAnimations()
            }
        }
        
        UIView.animate(withDuration: thirdDuration * 2, animations: {
            if hidden {
                navigationBarSubviews.forEach { $0.alpha = 0 }
            } else {
                snapshot?.alpha = 0
            }
        }, completion: nil)
        
        UIView.animate(withDuration: thirdDuration * 2, delay: thirdDuration, options: [], animations: {
            if hidden {
                snapshot?.alpha = 1
            } else {
                navigationBarSubviews.forEach { $0.alpha = 1 }
            }
        }, completion: { _ in
            if hidden {
                self.setNavigationBarHidden(hidden, animated: false)
            }
            (self.navigationBar as? NavigationBar)?.height = nil
            self.navigationBar.sizeToFit()
            snapshot?.removeFromSuperview()
            navigationBarSubviews.forEach { $0.alpha = 1 }
            completion()
        })
    }
    
    private func makeSnapshot(of view: UIView, isHidden: Bool) -> UIView? {
        let snapshot = view.snapshotView(afterScreenUpdates: false)
        snapshot?.frame = CGRect(x: 0, y: 0, width: view.frame.width, height: view.frame.height)
        snapshot?.alpha = isHidden ? 0 : 1
        snapshot.map(self.view.addSubview)
        return snapshot
    }
    
    // MARK: - Init
    
    override init(rootViewController: UIViewController) {
        super.init(navigationBarClass: NavigationBar.self, toolbarClass: nil)
        self.viewControllers = [rootViewController]
    }
    
    override init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: Bundle?) {
        super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
}

// MARK: - Navigation bar

class NavigationBar: UINavigationBar {
    
    var height: CGFloat?
    
    override func sizeThatFits(_ size: CGSize) -> CGSize {
        var size = super.sizeThatFits(size)
        if let height = height {
            size.height = height
        }
        return size
    }
}
