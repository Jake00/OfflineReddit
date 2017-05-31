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
    var state: State = .normal
    
    init(post: Post) {
        self.post = post
    }
    
    static let indentedWidth: CGFloat = 38
}

// MARK: - Equatable

extension PostCellModel: Equatable {
    
    static func == (lhs: PostCellModel, rhs: PostCellModel) -> Bool {
        return lhs.post == rhs.post
            && lhs.state == rhs.state
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
        return sortFilter.shouldFilter
            ? filter { sortFilter.filterer($0.post) }
                .sorted { sortFilter.comparitor($0.post, $1.post) }
            : sorted { sortFilter.comparitor($0.post, $1.post) }
    }
}

extension Array where Iterator.Element == PostCellModel {
    
    mutating func sortFilter(using sortFilter: Post.SortFilter) {
        if sortFilter.shouldFilter {
            self = filter { sortFilter.filterer($0.post) }
        }
        sort { sortFilter.comparitor($0.post, $1.post) }
    }
}
