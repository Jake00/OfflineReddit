//
//  Constants.swift
//  OfflineReddit
//
//  Created by Jake Bellamy on 19/03/17.
//  Copyright © 2017 Jake Bellamy. All rights reserved.
//

import Foundation

let intervalFormatter: DateComponentsFormatter = {
    let intervalFormatter = DateComponentsFormatter()
    intervalFormatter.unitsStyle = .short
    intervalFormatter.allowedUnits = [.year, .month, .day, .hour, .minute]
    intervalFormatter.maximumUnitCount = 1
    return intervalFormatter
}()

struct SharedText {
    static let agoFormat = NSLocalizedString("ago_format", value: "%@ ago", comment: "Used to say how much time has passed. e.g. '2 hrs ago'")
    static let unknown = NSLocalizedString("unknown", value: "Unknown", comment: "Used as a placeholder for null values")
    static let showMore = NSLocalizedString("show_more", value: "Show more", comment: "Show more")
}
