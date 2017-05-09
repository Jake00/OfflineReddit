//
//  AppDelegate.swift
//  OfflineReddit
//
//  Created by Jake Bellamy on 19/03/17.
//  Copyright © 2017 Jake Bellamy. All rights reserved.
//

import UIKit

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {
    
    var window: UIWindow?
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey: Any]?) -> Bool {
        
        if isDebugBuild, ProcessInfo.processInfo.arguments.contains("EMULATE_ONLINE") {
            /* For developing while the device is offline (unable to actually be online...) and needs to appear online for 'downloading' posts.
             * By switching this on `Reachability` will always report its status as being reachable via WiFi.
             */
            print("Enabling offline development. Application will report being online with no reachability change callbacks.")
            Reachability.shared.isEmulatingOnline = true
            // TODO inject this as part of instantiation.
            let postsViewController = (window?.rootViewController as? UINavigationController)?.viewControllers.first as? PostsViewController
            postsViewController?.provider.remote = OfflineRemoteProvider()
        } else {
            Reachability.shared.startNotifier()
        }
        
        return true
    }
}
