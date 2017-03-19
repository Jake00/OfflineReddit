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
        let parameters: Parameters? = after.map {["after": $0.name, "limit": "25"]}
        let request = Request(.get, path, parameters: parameters)
        return sendJSONRequest(request)
            .continueOnSuccessWith(.immediate, continuation: mapper.mapPosts)
    }
    
    func getComments(for post: Post, after: Comment? = nil) -> Task<[Comment]> {
        guard let url = post.urlValue else { return Task(error: Errors.missingFields) }
        let parameters: Parameters? = after.map {["after": $0.name, "limit": "100"]}
        let request = Request(.get, url + ".json", parameters: parameters)
        return sendJSONRequest(request)
            .continueOnSuccessWith(.immediate, continuation: mapper.mapComments)
    }
}
