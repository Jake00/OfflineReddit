//
//  APIClient+Endpoints.swift
//  ThisOrThat
//
//  Created by Jake Bellamy on 4/12/16.
//  Copyright © 2016 Jake Bellamy. All rights reserved.
//

import UIKit
import BoltsSwift

extension APIClient {
    
    func getPosts(for subreddits: [String], after: Post? = nil) -> Task<[Post]> {
        let path: String = "r/" + subreddits.joined(separator: "+") + ".json"
        let parameters: Parameters? = after.map {["after": $0.id, "limit": "25"]}
        let request = Request(.get, path, parameters: parameters)
        return sendJSONRequest(request)
            .continueOnSuccessWith(.immediate, continuation: mapper.mapPosts)
            .continueOnSuccessWith(.mainThread) { $0.inContext(CoreDataController.shared.viewContext) }
    }
    
    func getComments(for post: Post) -> Task<[Comment]> {
        guard let url = post.urlValue else { return Task(error: Errors.missingFields) }
        let request = Request(.get, url + ".json")
        return sendJSONRequest(request)
            .continueOnSuccessWith(.immediate, continuation: mapper.mapComments)
            .continueOnSuccessWith(.mainThread) { $0.inContext(CoreDataController.shared.viewContext) }
    }
    
    func getMoreComments(using more: MoreComments) -> Task<[Comment]> {
        guard let post = more.owningPost else { return Task(error: Errors.missingFields) }
        let request = Request(.get, "api/morechildren.json", parameters: [
            "api_type": "json",
            "children": more.children.joined(separator: ","),
            "link_id": post.id
            ])
        return sendJSONRequest(request).continueOnSuccessWith(.immediate) {
            try self.mapper.mapMoreComments(json: $0, more: more)
            }.continueOnSuccessWith(.mainThread) { $0.inContext(CoreDataController.shared.viewContext) }
    }
}
