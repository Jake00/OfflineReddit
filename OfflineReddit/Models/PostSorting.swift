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
        
        var includesTimePeriods: Bool {
            switch self {
            case .top, .worst, .controversial: return true
            case .hot, .new: return false
            }
        }
    }
    
    enum SortPeriod {
        case allTime
        case year
        case month
        case week
        case day
        case hour
        
        static let all: [SortPeriod] = [.allTime, .year, .month, .week, .day, .hour]
        
        var displayName: String {
            switch self {
            case .allTime: return SharedText.periodAllTime
            case .year:    return SharedText.periodYear
            case .month:   return SharedText.periodMonth
            case .week:    return SharedText.periodWeek
            case .day:     return SharedText.period24Hours
            case .hour:    return SharedText.periodHour
            }
        }
        
        var timeInterval: TimeInterval {
            switch self {
            case .allTime: return Date.distantPast.timeIntervalSinceNow
            case .year:    return -31536000 // 365 days
            case .month:   return -2592000 // 30 days
            case .week:    return -604800 // 7 days
            case .day:     return -86400 // 24 hours
            case .hour:    return -3600 // 60 minutes
            }
        }
        
        var filterer: ((Post) -> Bool) {
            guard self != .allTime else { return { _ in true }}
            let cutoff = Date(timeIntervalSinceNow: timeInterval)
            return { $0.created > cutoff }
        }
    }
    
    struct Filter: OptionSet {
        let rawValue: Int
        static let read    = Filter(rawValue: 1 << 0)
        static let notRead = Filter(rawValue: 1 << 1)
        static let offline = Filter(rawValue: 1 << 2)
        static let online  = Filter(rawValue: 1 << 3)
        static let none: Filter = [.read, .notRead, .offline, .online]
        
        var filterer: ((Post) -> Bool) {
            guard self != .none else { return { _ in true }}
            return { post in
                return ((self.contains(.read)    &&  post.isRead)
                    ||  (self.contains(.notRead) && !post.isRead))
                    && ((self.contains(.offline) &&  post.isAvailableOffline)
                    ||  (self.contains(.online)  && !post.isAvailableOffline))
            }
        }
    }
    
    struct FilterOption: Equatable {
        let value: Filter
        let displayName: String
        
        static func == (lhs: FilterOption, rhs: FilterOption) -> Bool {
            return lhs.value == rhs.value
        }
    }
    
    struct SortFilter: Equatable {
        var sort: Sort
        var period: SortPeriod?
        var filter: Filter
        
        var shouldFilter: Bool {
            return period != .allTime || filter != .none
        }
        
        var filterer: ((Post) -> Bool) {
            let periodFilter = sort.includesTimePeriods ? period?.filterer : nil
            return { post in
                self.filter.filterer(post) && periodFilter?(post) ?? true
            }
        }
        
        var comparitor: ((Post, Post) -> Bool) {
            return sort.comparitor
        }
        
        static func == (lhs: SortFilter, rhs: SortFilter) -> Bool {
            return lhs.sort == rhs.sort
                && lhs.period == rhs.period
                && lhs.filter == rhs.filter
        }
    }
}

extension Collection where Iterator.Element == Post {
    
    func sortFiltered(using sortFilter: Post.SortFilter) -> [Post] {
        return sortFilter.shouldFilter
            ? filter(sortFilter.filterer).sorted(by: sortFilter.comparitor)
            : sorted(by: sortFilter.comparitor)
    }
}

extension Array where Iterator.Element == Post {
    
    mutating func sortFilter(using sortFilter: Post.SortFilter) {
        if sortFilter.shouldFilter {
            self = filter(sortFilter.filterer)
        }
        sort(by: sortFilter.comparitor)
    }
}
