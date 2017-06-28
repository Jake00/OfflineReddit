//
//  AppDefaults.swift
//  OfflineReddit
//
//  Created by Jake Bellamy on 28/06/17.
//  Copyright © 2017 Jake Bellamy. All rights reserved.
//
// swiftlint:disable comma

import Foundation

struct Defaults {
    
    static let postsSortFilter = Post.SortFilter(
        sort: .top,
        period: .month,
        filter: [.notRead, .online, .offline])
    
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
