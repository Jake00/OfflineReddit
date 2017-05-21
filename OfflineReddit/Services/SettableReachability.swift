//
//  SettableReachability.swift
//  OfflineReddit
//
//  Created by Jake Bellamy on 13/05/17.
//  Copyright © 2017 Jake Bellamy. All rights reserved.
//

final class SettableReachability: Reachability {
    
    var isOnline: Bool = true
    
    var isOffline: Bool {
        return !isOnline
    }
}
