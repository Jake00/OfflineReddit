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
