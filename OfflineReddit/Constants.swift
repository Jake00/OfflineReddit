//
//  Constants.swift
//  OfflineReddit
//
//  Created by Jake Bellamy on 19/03/17.
//  Copyright © 2017 Jake Bellamy. All rights reserved.
//

import UIKit

let intervalFormatter: DateComponentsFormatter = {
    let intervalFormatter = DateComponentsFormatter()
    intervalFormatter.unitsStyle = .short
    intervalFormatter.allowedUnits = [.year, .month, .day, .hour, .minute]
    intervalFormatter.maximumUnitCount = 1
    return intervalFormatter
}()

var isDebugBuild: Bool {
    #if DEBUG
        return true
    #else
        return false
    #endif
}

var isTesting: Bool {
    return ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
}

struct SharedText {
    static let agoFormat = NSLocalizedString("ago_format", value: "%@ ago", comment: "Used to say how much time has passed. e.g. '2 hrs ago'")
    static let unknown = NSLocalizedString("unknown", value: "Unknown", comment: "Used as a placeholder for null values")
    static let showMore = NSLocalizedString("show_more", value: "Show more", comment: "Show more")
    static let repliesFormat = NSLocalizedString("x_more_replies_format", comment: "Format for how many replies are not shown. eg. '3 MORE REPLIES'")
    static let loadingCaps = NSLocalizedString("loading_caps", value: "LOADING", comment: "Loading text")
    static let loadingLowercase = NSLocalizedString("loading_lowercase", value: "Loading", comment: "Loading text")
    static let offline = NSLocalizedString("offline", value: "Offline", comment: "Offline")
    static let sortTitle = NSLocalizedString("sort_title", value: "Sort comments by", comment: "Title of sorting options")
    static let sortFormat = NSLocalizedString("sort_format", value: "Sort: %@", comment: "eg. Sort: Best")
    static let sortBest = NSLocalizedString("sort.best", value: "Best", comment: "Sort by best")
    static let sortHot = NSLocalizedString("sort.hot", value: "Hot", comment: "Sort by hot")
    static let sortTop = NSLocalizedString("sort.top", value: "Top", comment: "Sort by top")
    static let sortNew = NSLocalizedString("sort.new", value: "New", comment: "Sort by new")
    static let sortOld = NSLocalizedString("sort.old", value: "Old", comment: "Sort by old")
    static let sortControversial = NSLocalizedString("sort.controversial", value: "Controversial", comment: "Sort by controversial")
    static let sortWorst = NSLocalizedString("sort.worst", value: "Worst", comment: "Sort by worst")
}

extension UIColor {
    static let offWhite = UIColor(white: 0.95, alpha: 1)
    static let selectedGray = UIColor(white: 0.93, alpha: 1)
    static let offBlack = UIColor(white: 0.15, alpha: 1)
    static let separator = UIColor(red: 0.78, green: 0.78, blue: 0.8, alpha: 1)
}
