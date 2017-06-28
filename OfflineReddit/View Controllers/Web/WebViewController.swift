//
//  WebViewController.swift
//  OfflineReddit
//
//  Created by Jake Bellamy on 19/06/17.
//  Copyright © 2017 Jake Bellamy. All rights reserved.
//

import UIKit
import WebKit

class WebViewController: UIViewController {
    
    static let processPool = WKProcessPool()
    
    private var observer: PropertyObserver?
    
    var webView: WKWebView {
        // swiftlint:disable:next force_cast
        return view as! WKWebView
    }
    
    var initialURL: URL?
    
    // MARK: - Init
    
    convenience init(initialURL: URL?) {
        self.init(nibName: nil, bundle: nil)
        self.initialURL = initialURL
    }
    
    // MARK: - View controller
    
    override func loadView() {
        let config = WKWebViewConfiguration()
        config.processPool = WebViewController.processPool
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.uiDelegate = self
        webView.navigationDelegate = self
        view = webView
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        observer = PropertyObserver(observed: webView)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        isObserving = true
        if let url = initialURL, webView.url == nil {
            webView.load(URLRequest(url: url))
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        isObserving = false
    }
    
    // MARK: - Observations
    
    var isObserving: Bool {
        get { return observer?.events.isEmpty == false }
        set {
            observer?.events = !newValue ? [:] : [
                "loading": { _, new in
                    UIApplication.shared.isNetworkActivityIndicatorVisible = new as? Bool ?? false
                },
                "estimatedProgress": updateNavigationBarProgress,
                "title": { _, new in
                    self.title = new as? String
                }]
            updateNavigationBarProgress()
            if !newValue {
                UIApplication.shared.isNetworkActivityIndicatorVisible = false
            }
        }
    }
    
    func updateNavigationBarProgress(_ old: Any? = nil, _ new: Any? = nil) {
        let progress = webView.estimatedProgress
        let hide = !isObserving || progress <= 0 || progress >= 1
        navigationBarProgressView?.isHidden = hide
        navigationBarProgressView?.setProgress(hide ? 0 : Float(progress), animated: true)
    }
}

extension WebViewController: WKUIDelegate {
    
    func webView(
        _ webView: WKWebView,
        createWebViewWith configuration: WKWebViewConfiguration,
        for navigationAction: WKNavigationAction,
        windowFeatures: WKWindowFeatures
        ) -> WKWebView? {
        
        return webView
    }
}

extension WebViewController: WKNavigationDelegate {
    
}
