//
//  PostCellModel.swift
//  OfflineReddit
//
//  Created by Jake Bellamy on 6/05/17.
//  Copyright © 2017 Jake Bellamy. All rights reserved.
//

import UIKit

final class PostCellModel {
    
    enum State {
        case normal
        case indented
        case loading
        case checked
    }
    
    let post: Post
    var state: State
    
    init(post: Post, state: State) {
        self.post = post
        self.state = state
    }
    
    convenience init(post: Post) {
        self.init(post: post, state: .normal)
    }
    
    static let indentedWidth: CGFloat = 38
}

// MARK: - Equatable

extension PostCellModel: Equatable {
    
    static func == (lhs: PostCellModel, rhs: PostCellModel) -> Bool {
        return lhs.post == rhs.post
    }
}

// MARK: - Hashable

extension PostCellModel: Hashable {
    
    var hashValue: Int {
        return post.hashValue
    }
}

// MARK: - Comparable

extension PostCellModel: Comparable {
    
    static func < (lhs: PostCellModel, rhs: PostCellModel) -> Bool {
        return lhs.post < rhs.post
    }
}

extension Collection where Iterator.Element == PostCellModel {
    
    func sortFiltered(using sortFilter: Post.SortFilter) -> [PostCellModel] {
        let comparitor = sortFilter.comparitor
        if sortFilter.shouldFilter {
            let filterer = sortFilter.filterer
            return filter { filterer($0.post) }
                .sorted { comparitor($0.post, $1.post) }
        } else {
            return sorted { comparitor($0.post, $1.post) }
        }
    }
}

extension Array where Iterator.Element == PostCellModel {
    
    mutating func sortFilter(using sortFilter: Post.SortFilter) {
        let comparitor = sortFilter.comparitor
        if sortFilter.shouldFilter {
            let filterer = sortFilter.filterer
            self = filter { filterer($0.post) }
        }
        sort { comparitor($0.post, $1.post) }
    }
}
