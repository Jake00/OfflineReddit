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

struct SharedText {
    static let agoFormat = NSLocalizedString("ago_format", value: "%@ ago", comment: "Used to say how much time has passed. e.g. '2 hrs ago'")
    static let unknown = NSLocalizedString("unknown", value: "Unknown", comment: "Used as a placeholder for null values")
    static let showMore = NSLocalizedString("show_more", value: "Show more", comment: "Show more")
    static let repliesFormat = NSLocalizedString("x_more_replies_format", comment: "Format for how many replies are not shown. eg. '3 MORE REPLIES'")
    static let loadingCaps = NSLocalizedString("loading_caps", value: "LOADING", comment: "Loading text")
    static let loadingLowercase = NSLocalizedString("loading_lowercase", value: "Loading", comment: "Loading text")
    static let offline = NSLocalizedString("offline", value: "Offline", comment: "Offline")
}

extension UIColor {
    static let offWhite = UIColor(white: 0.95, alpha: 1)
    static let selectedGray = UIColor(white: 0.93, alpha: 1)
    static let offBlack = UIColor(white: 0.15, alpha: 1)
    static let separator = UIColor(red: 0.78, green: 0.78, blue: 0.8, alpha: 1)
}
