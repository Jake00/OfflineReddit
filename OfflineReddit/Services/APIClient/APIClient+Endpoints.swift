//
//  APIClient+Endpoints.swift
//  ThisOrThat
//
//  Created by Jake Bellamy on 4/12/16.
//  Copyright © 2016 Jake Bellamy. All rights reserved.
//

import BoltsSwift

extension APIClient: DataProviding {
    
    func getPosts(for subreddits: [Subreddit], after post: Post?) -> Task<[Post]> {
        let path: String = "r/" + subreddits.map { $0.name }.joined(separator: "+") + ".json"
        var parameters: Parameters = ["raw_json": "1"]
        if let after = after {
            parameters["after"] = after.id
            parameters["limit"] = "25"
        }
        let request = Request(.get, path, parameters: parameters)
        return sendJSONRequest(request)
            .continueOnSuccessWith(.immediate, continuation: mapper.mapPosts)
            .continueOnSuccessWith(.mainThread) { $0.inContext(CoreDataController.shared.viewContext) }
    }
    
    func getComments(for post: Post) -> Task<[Comment]> {
        guard let permalink = post.permalink else { return Task(error: Errors.missingFields) }
        let request = Request(.get, permalink + ".json", parameters: ["raw_json": "1"])
        return sendJSONRequest(request)
            .continueOnSuccessWith(.immediate, continuation: mapper.mapComments)
            .continueOnSuccessWith(.mainThread) { $0.inContext(CoreDataController.shared.viewContext) }
    }
    
    func getMoreComments(using mores: [MoreComments], post: Post) -> Task<[Comment]> {
        guard !mores.isEmpty else { return Task(error: Errors.missingFields) }
        let request = Request(.post, "api/morechildren.json", parameters: [
            "api_type": "json",
            "children": mores.flatMap { $0.children }.joined(separator: ","),
            "link_id": post.id,
            "raw_json": "1"
            ])
        return sendJSONRequest(request).continueOnSuccessWith(.immediate) {
            try self.mapper.mapMoreComments(json: $0, mores: mores, post: post)
            }.continueOnSuccessWith(.mainThread) { $0.inContext(CoreDataController.shared.viewContext) }
    }
}
