//
//  OfflineRemoteProvider.swift
//  OfflineReddit
//
//  Created by Jake Bellamy on 8/05/17.
//  Copyright © 2017 Jake Bellamy. All rights reserved.
//

import Foundation
import CoreData
import BoltsSwift

final class OfflineRemoteProvider {
    
    enum Error: Swift.Error, PresentableError {
        case noFileExists
        var alertTitle: String? { return nil }
        var alertMessage: String? {
            return "File not found"
        }
    }
    
    let queue = DispatchQueue(label: "com.jrb.OfflineRemoteProvider")
    let mapper = Mapper()
    static let subdirectory = "Offline Development"
    lazy var context: NSManagedObjectContext = CoreDataController.shared.viewContext
    
    var delays = true
    var logs = true
    
    static var cache: [String: Any] = [:]
    
    fileprivate func delay() -> Task<Void> {
        return Task<Void>.withDelay(delays ? 1 : 0)
    }
    
    fileprivate func log(_ s: String, newline: Bool = true) {
        guard logs else { return }
        if newline {
            print(s)
        } else {
            print(s, terminator: "")
        }
    }
    
    func readFile(named filename: String) -> Task<Any> {
        log("loading file \(filename).json: ", newline: false)
        if let cached = OfflineRemoteProvider.cache[filename] {
            log("success from cache")
            return Task<Any>(cached)
        }
        guard let url = Bundle.main.url(forResource: filename, withExtension: "json", subdirectory: OfflineRemoteProvider.subdirectory) else {
            log("no file exists")
            return Task(error: Error.noFileExists)
        }
        let source = TaskCompletionSource<Any>()
        queue.async {
            do {
                let data = try Data(contentsOf: url)
                let json = try JSONSerialization.jsonObject(with: data, options: [])
                self.log("success")
                OfflineRemoteProvider.cache[filename] = json
                source.set(result: json)
            } catch {
                self.log("\(error)")
                source.set(error: error)
            }
        }
        return source.task
    }
    
    static func postsFilename() -> String {
        // File `Posts.json` contains a response from
        // GET https://www.reddit.com/r/AskReddit+relationships.json?raw_json=1
        return "Posts"
    }
    
    static func commentsFilename(post: Post) -> String {
        // Comments files are named Post_`id`.json
        return "Post_\(post.id)"
    }
    
    static func moreCommentsFilename(post: Post, mores: [MoreComments]) -> String? {
        // More comments files are named Children_`postId`_`firstChildId`.json
        let filenameFor: (String) -> String = { "Children_\(post.id)_\($0)" }
        let stored = Bundle.main.urls(forResourcesWithExtension: "json", subdirectory: subdirectory)?.map { $0.lastPathComponent } ?? []
        return mores.flatMap { $0.children }.map(filenameFor).first { child in
            stored.contains { child + ".json" == $0 }
        }
    }
}

// MARK: - Data providing

extension OfflineRemoteProvider: DataProviding {

    func getPosts(for subreddits: [Subreddit], after post: Post?) -> Task<[Post]> {
        let filename = OfflineRemoteProvider.postsFilename()
        return delay().continueWithTask { _ in self.readFile(named: filename) }
            .continueOnSuccessWith(.immediate, continuation: mapper.mapPosts)
            .continueOnSuccessWith(.immediate) { $0.inContext(self.context, inContextsQueue: true) }
    }
    
    func getComments(for post: Post) -> Task<[Comment]> {
        let filename = OfflineRemoteProvider.commentsFilename(post: post)
        return delay().continueWithTask { _ in self.readFile(named: filename) }
            .continueOnSuccessWith(.immediate, continuation: mapper.mapComments)
            .continueOnSuccessWith(.immediate) { $0.inContext(self.context, inContextsQueue: true) }
    }
    
    func getMoreComments(using mores: [MoreComments], post: Post) -> Task<[Comment]> {
        guard let filename = OfflineRemoteProvider.moreCommentsFilename(post: post, mores: mores) else {
            return Task(error: Error.noFileExists)
        }
        return delay().continueWithTask { _ in self.readFile(named: filename) }
            .continueOnSuccessWith(.immediate) { try self.mapper.mapMoreComments(json: $0, mores: mores, post: post) }
            .continueOnSuccessWith(.immediate) { $0.inContext(self.context, inContextsQueue: true) }
    }
}
