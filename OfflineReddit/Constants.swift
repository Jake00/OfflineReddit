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

let pixel = 1 / UIScreen.main.scale

struct Defaults {
    static let postsSortFilter = Post.SortFilter(sort: .top, period: .month, filter: [.notRead, .online, .offline])
    static let commentsSort: Comment.Sort = .top
    
    static var subreddits: [(name: String, contentType: Subreddit.ContentType)] {
        return [
            ("AskReddit",               .text),
            ("askscience",              .text),
            ("explainlikeimfive",       .text),
            ("IAmA",                    .text),
            ("Jokes",                   .text),
            ("LifeProTips",             .text),
            ("nosleep",                 .text),
            ("personalfinance",         .text),
            ("Showerthoughts",          .text),
            ("tifu",                    .text),
            ("todayilearned",           .text),
            ("WritingPrompts",          .text),
            ("PettyRevenge",            .text),
            ("ProRevenge",              .text),
            ("TalesfromRetail",         .text),
            ("TalesfromTechSupport",    .text),
            ("TalesfromTheFrontDesk",   .text),
            ("talesfromyourserver",     .text),
            ("relationships",           .text),
            ("changemyview",            .text),
            ("bestof",                  .text),
            ("bestoflegaladvice",       .text),
            ("subredditdrama",          .text),
            ("threadkillers",           .text),
            ("Glitch_in_the_Matrix",    .text),
            ("unresolvedmysteries",     .text),
            ("legaladvice",             .text),
            ("no_sob_storyez",          .text),
            ("ExplainlikeIAMA",         .text),
            ("fatpeoplestories",        .text),
            ("wouldyourather",          .text),
            ("Art",                     .multimedia),
            ("aww",                     .multimedia),
            ("dataisbeautiful",         .multimedia),
            ("DIY",                     .multimedia),
            ("EarthPorn",               .multimedia),
            ("food",                    .multimedia),
            ("funny",                   .multimedia),
            ("Futurology",              .multimedia),
            ("gadgets",                 .multimedia),
            ("gaming",                  .multimedia),
            ("GetMotivated",            .multimedia),
            ("gifs",                    .multimedia),
            ("InternetIsBeautiful",     .multimedia),
            ("listentothis",            .multimedia),
            ("mildlyinteresting",       .multimedia),
            ("movies",                  .multimedia),
            ("Music",                   .multimedia),
            ("news",                    .multimedia),
            ("worldnews",               .multimedia),
            ("nottheonion",             .multimedia),
            ("OldSchoolCool",           .multimedia),
            ("photoshopbattles",        .multimedia),
            ("pics",                    .multimedia),
            ("science",                 .multimedia),
            ("space",                   .multimedia),
            ("sports",                  .multimedia),
            ("television",              .multimedia),
            ("TwoXChromosomes",         .multimedia),
            ("technology",              .multimedia)
        ]
    }
}

struct SharedText {
    static let agoFormat = NSLocalizedString("ago_format", value: "%@ ago", comment: "Used to say how much time has passed. e.g. '2 hrs ago'")
    static let unknown = NSLocalizedString("unknown", value: "Unknown", comment: "Used as a placeholder for null values")
    static let showMore = NSLocalizedString("show_more", value: "Show more", comment: "Show more")
    static let repliesFormat = NSLocalizedString("x_more_replies_format", comment: "Format for how many replies are not shown. eg. '3 MORE REPLIES'")
    static let loadingCaps = NSLocalizedString("loading_caps", value: "LOADING", comment: "Loading text")
    static let loadingLowercase = NSLocalizedString("loading_lowercase", value: "Loading", comment: "Loading text")
    static let offline = NSLocalizedString("offline", value: "Offline", comment: "Offline")
    static let undo = NSLocalizedString("undo", value: "Undo", comment: "Undo")
    static let sortCommentsTitle = NSLocalizedString("sort_comments_title", value: "Sort comments by", comment: "Title of sorting options for comments")
    static let sortPostsTitle = NSLocalizedString("sort_posts_title", value: "Sort posts by", comment: "Title of sorting options for posts")
    static let sortFormat = NSLocalizedString("sort_format", value: "Sort: %@", comment: "eg. Sort: Best")
    static let sortBest = NSLocalizedString("sort.best", value: "Best", comment: "Sort by best")
    static let sortHot = NSLocalizedString("sort.hot", value: "Hot", comment: "Sort by hot")
    static let sortTop = NSLocalizedString("sort.top", value: "Top", comment: "Sort by top")
    static let sortNew = NSLocalizedString("sort.new", value: "New", comment: "Sort by new")
    static let sortOld = NSLocalizedString("sort.old", value: "Old", comment: "Sort by old")
    static let sortControversial = NSLocalizedString("sort.controversial", value: "Controversial", comment: "Sort by controversial")
    static let sortWorst = NSLocalizedString("sort.worst", value: "Worst", comment: "Sort by worst")
    static let periodAllTime = NSLocalizedString("period.all_time", value: "All time", comment: "Include sorted posts for all time")
    static let periodYear = NSLocalizedString("period.year", value: "Past year", comment: "Include sorted posts for past year")
    static let periodMonth = NSLocalizedString("period.month", value: "Past month", comment: "Include sorted posts for past month")
    static let periodWeek = NSLocalizedString("period.week", value: "Past week", comment: "Include sorted posts for past week")
    static let period24Hours = NSLocalizedString("period.24_hours", value: "Past 24 hours", comment: "Include sorted posts for past 24 hours")
    static let periodHour = NSLocalizedString("period.hour", value: "Past hour", comment: "Include sorted posts for past hour")
    static let readPost = NSLocalizedString("read_post", value: "Post marked as read", comment: "Post marked as read")
    static let read = NSLocalizedString("read", value: "Read", comment: "Read option")
    static let notRead = NSLocalizedString("not_read", value: "Not read", comment: "Not read option")
    static let both = NSLocalizedString("both", value: "Both", comment: "Both option")
    static let savedOffline = NSLocalizedString("saved_offline", value: "Saved offline", comment: "Saved offline option")
    static let onlineOnly = NSLocalizedString("online", value: "Online only", comment: "Online option")
    static let readStatus = NSLocalizedString("read_status", value: "Read status", comment: "Read status")
    static let offlineStatus = NSLocalizedString("offline_status", value: "Offline status", comment: "Offline status")
    static let onlineFilterDisabledReason = NSLocalizedString("online_filter_disabled_reason", value: "Only saved posts are available until you are back online.", comment: "Offline status")
    static let savePostsFormat = NSLocalizedString("save_x_posts_format", comment: "Format for number of posts selected to download")
    static let subredditContentTypeUnknown = NSLocalizedString("subreddit_content_type.unknown", value: "Unknown", comment: "Section header for unknown content type of subreddits")
    static let subredditContentTypeText = NSLocalizedString("subreddit_content_type.text", value: "Text based", comment: "Section header for text based subreddits")
    static let subredditContentTypeMultimedia = NSLocalizedString("subreddit_content_type.multimedia", value: "Pictures and websites", comment: "Section header for multimedia based subreddits (eg. pictures and websites)")
}

extension UIColor {
    static let offWhite = UIColor(white: 0.95, alpha: 1)
    static let selectedGray = UIColor(white: 0.93, alpha: 1)
    static let lightMidGray = UIColor(white: 0.6, alpha: 1)
    static let offBlack = UIColor(white: 0.15, alpha: 1)
    static let separator = UIColor(red: 0.78, green: 0.78, blue: 0.8, alpha: 1)
}
