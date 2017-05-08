//
//  OfflineDevelopmentDataProvider.swift
//  OfflineReddit
//
//  Created by Jake Bellamy on 8/05/17.
//  Copyright © 2017 Jake Bellamy. All rights reserved.
//

import Foundation
import BoltsSwift

final class OfflineDevelopmentDataProvider {
    
    enum Error: Swift.Error, PresentableError {
        case noFileExists
        var alertTitle: String? { return nil }
        var alertMessage: String? {
            return "File not found"
        }
    }
    
    let queue = DispatchQueue(label: "com.jrb.OfflineDevelopmentDataProvider")
    let mapper = Mapper()
    let subdirectory = "Offline Development"
    
    fileprivate func delay() -> Task<Void> {
        return Task<Void>.withDelay(1)
    }
    
    fileprivate func readFile(named filename: String) -> Task<Any> {
        print("loading file \(filename).json: ", terminator: "")
        guard let url = Bundle.main.url(forResource: filename, withExtension: "json", subdirectory: subdirectory) else {
            print("no file exists")
            return Task(error: Error.noFileExists)
        }
        let source = TaskCompletionSource<Any>()
        queue.async {
            do {
                let data = try Data(contentsOf: url)
                let json = try JSONSerialization.jsonObject(with: data, options: [])
                print("success")
                source.set(result: json)
            } catch {
                print("\(error)")
                source.set(error: error)
            }
        }
        return source.task
    }
}

// MARK: - Data provider

extension OfflineDevelopmentDataProvider: DataProvider {

    func getPosts(for subreddits: [Subreddit], after: Post?) -> Task<[Post]> {
        // File `Posts.json` contains a response from
        // GET https://www.reddit.com/r/AskReddit+relationships.json?raw_json=1
        return delay().continueWithTask { _ in self.readFile(named: "Posts") }
            .continueOnSuccessWith(.immediate, continuation: mapper.mapPosts)
            .continueOnSuccessWith(.mainThread) { $0.inContext(CoreDataController.shared.viewContext) }
    }
    
    func getComments(for post: Post) -> Task<[Comment]> {
        // Comments files are named Post_`id`.json
        return delay().continueWithTask { _ in self.readFile(named: "Post_\(post.id)") }
            .continueOnSuccessWith(.immediate, continuation: mapper.mapComments)
            .continueOnSuccessWith(.mainThread) { $0.inContext(CoreDataController.shared.viewContext) }
    }
    
    func getMoreComments(using mores: [MoreComments], post: Post) -> Task<[Comment]> {
        // More comments files are named Children_`postId`_`firstChildId`.json
        let filenameFor: (String) -> String = { "Children_\(post.id)_\($0)" }
        let children = mores.flatMap { $0.children }.map(filenameFor)
        let stored = Bundle.main.urls(forResourcesWithExtension: "json", subdirectory: subdirectory)?.map { $0.lastPathComponent } ?? []
        let found = children.first { child in
            stored.contains { child + ".json" == $0 }
        }
        guard let filename = found else {
            return Task(error: Error.noFileExists)
        }
        return delay().continueWithTask { _ in self.readFile(named: filename) }
            .continueOnSuccessWith(.immediate) { try self.mapper.mapMoreComments(json: $0, mores: mores, post: post) }
            .continueOnSuccessWith(.mainThread) { $0.inContext(CoreDataController.shared.viewContext) }
    }
}
