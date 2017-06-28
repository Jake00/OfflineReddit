//
//  Task+Void.swift
//  OfflineReddit
//
//  Created by Jake Bellamy on 3/06/17.
//  Copyright © 2017 Jake Bellamy. All rights reserved.
//

import BoltsSwift

extension Task {
    
    func asVoid() -> Task<Void> {
        return continueOnSuccessWith(.immediate) { _ in }
    }
}
