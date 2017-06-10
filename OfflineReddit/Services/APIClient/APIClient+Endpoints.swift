//
//  APIClient+Endpoints.swift
//  ThisOrThat
//
//  Created by Jake Bellamy on 4/12/16.
//  Copyright © 2016 Jake Bellamy. All rights reserved.
//

import BoltsSwift

// https://www.reddit.com/dev/api/

extension APIClient: RemoteDataProviding {
    
    func getPosts(for subreddits: [Subreddit], after post: Post?, sortedBy sort: Post.Sort, period: Post.SortPeriod?) -> Task<[Post]> {
        let path: String = "r/\(subreddits.map { $0.name }.joined(separator: "+"))/\(sort.apiKey).json"
        var parameters: Parameters = ["raw_json": "1"]
        if let post = post {
            parameters["after"] = post.id
            parameters["limit"] = "25"
        }
        if sort.includesTimePeriods, let period = period {
            parameters["t"] = period.apiKey
        }
        let request = Request(.get, path, parameters: parameters)
        return sendJSONRequest(request)
            .continueOnSuccessWith(.immediate, continuation: mapper.mapPosts)
            .continueOnSuccessWith(.mainThread) { $0.inContext(CoreDataController.shared.viewContext) }
    }
    
    func getComments(for post: Post, sortedBy sort: Comment.Sort) -> Task<[Comment]> {
        guard let permalink = post.permalink else { return Task(error: Errors.missingFields) }
        let request = Request(.get, permalink + ".json", parameters: [
            "raw_json": "1",
            "sort": sort.apiKey
            ])
        return sendJSONRequest(request)
            .continueOnSuccessWith(.immediate, continuation: mapper.mapComments)
            .continueOnSuccessWith(.mainThread) { $0.inContext(CoreDataController.shared.viewContext) }
    }
    
    func getMoreComments(using mores: [MoreComments], post: Post, sortedBy sort: Comment.Sort) -> Task<[Comment]> {
        guard !mores.isEmpty else { return Task(error: Errors.missingFields) }
        let request = Request(.post, "api/morechildren.json", parameters: [
            "api_type": "json",
            "children": mores.flatMap { $0.children }.joined(separator: ","),
            "link_id": post.id,
            "raw_json": "1",
            "sort": sort.apiKey
            ])
        return sendJSONRequest(request).continueOnSuccessWith(.immediate) {
            try self.mapper.mapMoreComments(json: $0, mores: mores, post: post)
            }.continueOnSuccessWith(.mainThread) { $0.inContext(CoreDataController.shared.viewContext) }
    }
}

private extension Post.Sort {
    var apiKey: String {
        switch self {
        case .hot: return "hot"
        case .top: return "top"
        case .worst, .controversial: return "controversial"
        case .new: return "new"
        }
    }
}

private extension Post.SortPeriod {
    var apiKey: String {
        switch self {
        case .allTime: return "all"
        case .year:    return "year"
        case .month:   return "month"
        case .week:    return "week"
        case .day:     return "day"
        case .hour:    return "hour"
        }
    }
}

private extension Comment.Sort {
    var apiKey: String {
        switch self {
        case .top: return "top"
        case .new: return "new"
        case .old: return "old"
        case .controversial, .worst: return "controversial"
        }
    }
}
