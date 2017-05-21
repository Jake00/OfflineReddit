//
//  BaseTestCase.swift
//  OfflineReddit
//
//  Created by Jake Bellamy on 16/05/17.
//  Copyright © 2017 Jake Bellamy. All rights reserved.
//

import XCTest
@testable import OfflineReddit

class BaseTestCase: XCTestCase {
    
    let group = DispatchGroup()
    let reachability = SettableReachability()
    let controller = TestableCoreDataController()
    private(set) var remote: OfflineRemoteProvider!
    
    var provider: DataProvider {
        return DataProvider(remote: remote, local: controller.context, reachability: reachability)
    }
    
    override func setUp() {
        super.setUp()
        reachability.isOnline = true
        controller.reset()
        controller.context.dispatchGroup = group
        remote = OfflineRemoteProvider()
        remote.delays = false
        remote.context = controller.context
        remote.mapper.context = controller.context
    }
    
    override func tearDown() {
        waitForGroup(timeout: 0.5)
        remote = nil
        super.tearDown()
    }
    
    @discardableResult
    func waitForGroup(timeout: TimeInterval) -> Bool {
        var completed = false
        let end = Date(timeIntervalSinceNow: timeout)
        group.notify(queue: .main) {
            completed = true
        }
        while !completed, end.timeIntervalSinceNow > 0 {
            let interval = 0.002
            let date = Date(timeIntervalSinceNow: interval)
            if !RunLoop.main.run(mode: .defaultRunLoopMode, before: date) {
                Thread.sleep(forTimeInterval: interval)
            }
        }
        return completed
    }
}
