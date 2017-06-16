//
//  CommentCellModel.swift
//  OfflineReddit
//
//  Created by Jake Bellamy on 6/06/17.
//  Copyright © 2017 Jake Bellamy. All rights reserved.
//

import UIKit
import CocoaMarkdown.CMAttributedStringRenderResult

final class CommentsCellModel {
    
    let comment: Either<Comment, MoreComments>
    
    init(comment: Either<Comment, MoreComments>) {
        self.comment = comment
    }
    
    var isMoreComments: Bool {
        return comment.first == nil
    }
    
    private var _isExpanded: Bool = true
    
    var isExpanded: Bool {
        get { return isMoreComments || _isExpanded }
        set { _isExpanded = newValue }
    }
    
    var isExpandable: Bool {
        return comment.first != nil
    }
    
    typealias Width = CGFloat
    typealias Height = CGFloat
    
    var expandedHeight: [Width: Height] = [:]
    static var condensedHeight: Height?
    
    func height(for width: Width) -> Height? {
        return isExpanded ? expandedHeight[width] : CommentsCellModel.condensedHeight
    }
    
    var depth: Int64 {
        switch comment {
        case .first(let a): return a.depth
        case .other(let b): return b.depth
        }
    }
    
    var render: CMAttributedStringRenderResult?
}

// MARK: - Equatable

extension CommentsCellModel: Equatable {
    
    static func == (lhs: CommentsCellModel, rhs: CommentsCellModel) -> Bool {
        return lhs.comment == rhs.comment
    }
}

// MARK: - Hashable

extension CommentsCellModel: Hashable {
    
    var hashValue: Int {
        switch comment {
        case .first(let a): return a.hashValue
        case .other(let b): return b.hashValue
        }
    }
}

// MARK: - Debug description

extension CommentsCellModel: CustomDebugStringConvertible {
    
    var debugDescription: String {
        return "\(type(of: self)) - comment: \(comment)"
    }
}

// MARK: - Comparable

extension CommentsCellModel: Comparable {
    
    static func < (lhs: CommentsCellModel, rhs: CommentsCellModel) -> Bool {
        return lhs.comment < rhs.comment
    }
}

extension Collection where Iterator.Element == CommentsCellModel {
    
    func sorted(by sorting: Comment.Sort) -> [CommentsCellModel] {
        let comparitor = sorting.comparitor
        return sorted { compare($0.comment, $1.comment, comparitor) }
    }
}
