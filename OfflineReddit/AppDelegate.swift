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
        
        startReachability()
        
        window = UIWindow(frame: UIScreen.main.bounds)
        window?.rootViewController = {
            let navigationController = NavigationController(rootViewController: PostsViewController())
            return navigationController
        }()
        window?.makeKeyAndVisible()
        
        return true
    }
    
    func startReachability() {
        /*
         For developing while the device is offline (unable to actually be online...) and needs to appear online for 'downloading' posts.
         By switching on emulating online `Reachability` will always report its status as being reachable via WiFi.
         */
        if isDebugBuild && ProcessInfo.processInfo.arguments.contains("EMULATE_ONLINE") {
            print("Enabling offline development. Application will report being online with no reachability change callbacks.")
            if Reachability.shared.isNotifiying {
                Reachability.shared.stopNotifier()
            }
            Reachability.shared.isEmulatingOnline = true
            DataProvider.shared.remote = OfflineRemoteProvider()
        } else {
            Reachability.shared.startNotifier()
        }
    }
}
