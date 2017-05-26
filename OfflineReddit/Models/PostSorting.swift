//
//  PostSorting.swift
//  OfflineReddit
//
//  Created by Jake Bellamy on 25/05/17.
//  Copyright © 2017 Jake Bellamy. All rights reserved.
//

import Foundation

extension Post: Comparable {
    
    static func < (lhs: Post, rhs: Post) -> Bool {
        return Sort.hot.comparitor(lhs, rhs)
    }
    
    enum Sort {
        case hot
        case top
        case worst
        case new
        case controversial
        
        static let all: [Sort] = [.hot, .top, .worst, .new, .controversial]
        
        var displayName: String {
            switch self {
            case .hot:   return SharedText.sortHot
            case .top:   return SharedText.sortTop
            case .worst: return SharedText.sortWorst
            case .new:   return SharedText.sortNew
            case .controversial: return SharedText.sortControversial
            }
        }
        
        var descriptor: NSSortDescriptor? {
            switch self {
            case .hot:   return NSSortDescriptor(key: "orderHot", ascending: false)
            case .top:   return NSSortDescriptor(key: "score", ascending: false)
            case .worst: return NSSortDescriptor(key: "score", ascending: true)
            case .new:   return NSSortDescriptor(key: "created", ascending: true)
            case .controversial: return nil
            }
        }
        
        var comparitor: ((Post, Post) -> Bool) {
            switch self {
            case .hot:   return { $0.orderHot > $1.orderHot }
            case .top:   return { $0.score > $1.score }
            case .worst: return { $0.score < $1.score }
            case .new:   return { $0.created > $1.created }
            case .controversial: return { $0.orderControversial > $1.orderControversial }
            }
        }
    }
}
