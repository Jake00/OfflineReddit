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
        
        let provider = enableDataProviding()
        
        window = UIWindow(frame: UIScreen.main.bounds)
        window?.rootViewController = NavigationController(rootViewController: PostsViewController(provider: provider))
        window?.makeKeyAndVisible()
        
        return true
    }
    
    private func enableDataProviding() -> DataProvider {
        if isDebugBuild && ProcessInfo.processInfo.arguments.contains("EMULATE_ONLINE") {
            print("Enabling offline development. Application will report being online with no reachability change callbacks.")
            return DataProvider(
                remote: OfflineRemoteProvider(),
                local: CoreDataController.shared.viewContext,
                reachability: SettableReachability())
        }
        
        let reachability = NetworkReachability.forInternetConnection()
        reachability.startNotifier()
        return DataProvider(
            remote: APIClient(),
            local: CoreDataController.shared.viewContext,
            reachability: reachability)
    }
}
