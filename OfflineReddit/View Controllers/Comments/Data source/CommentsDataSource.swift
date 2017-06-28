//
//  CommentsDataSource.swift
//  OfflineReddit
//
//  Created by Jake Bellamy on 9/05/17.
//  Copyright © 2017 Jake Bellamy. All rights reserved.
//

import UIKit
import BoltsSwift
import CocoaMarkdown

protocol CommentsDataSourceDelegate: class {
    
    func viewDimensionsForCommentsDataSource(
        _ dataSource: CommentsDataSource
        ) -> (horizontalMargins: CGFloat, frameWidth: CGFloat)
    
    func commentsDataSource(
        _ dataSource: CommentsDataSource,
        isFetchingWith task: Task<Void>)
    
    func commentsDataSource(
        _ dataSource: CommentsDataSource,
        didUpdateAllCommentsWith saved: Int64,
        _ toExpand: Int64)
}

// MARK: -

class CommentsDataSource: NSObject {
    
    // MARK: Init
    
    let post: Post
    let provider: CommentsProvider
    let reachability: Reachability
    
    init(post: Post, provider: DataProvider) {
        self.post = post
        self.provider = CommentsProvider(provider: provider)
        self.reachability = provider.reachability
        super.init()
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(reachabilityChanged(_:)),
            name: .ReachabilityChanged,
            object: nil)
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(preferredTextSizeChanged(_:)),
            name: .UIContentSizeCategoryDidChange,
            object: nil)
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    // MARK: - Instance variables
    
    /// Master list of all the comments available to display, before filtering.
    var allComments: [CommentsCellModel] = []
    
    /// List of comments which drives the table view. Is a subset of `allComments` 
    /// when a comment is condensed and its children hidden.
    var comments: [CommentsCellModel] = []
    
    /// The 'more comments' cells which are loading their children.
    var loadingCells: Set<MoreComments> = []
    
    var sort = Defaults.commentsSort {
        didSet { updateComments() }
    }
    
    weak var tableView: UITableView?
    weak var delegate: CommentsDataSourceDelegate?
    weak var urlLabelDelegate: URLLabelDelegate?
    
    var downloader: CommentsDownloader?
    
    let textRectCache = TextRectCache()
    
    let heightCachingQueue = DispatchQueue(
        label: "CommentsDataSource.heightCachingQueue",
        qos: .userInitiated)
    
    var hasFetchedOnceSuccessfully = false
    
    // MARK: - Body label text attributes
    
    fileprivate var cachedTextAttributes: CMTextAttributes?
    
    var textAttributes: CMTextAttributes {
        if let textAttributes = cachedTextAttributes {
            return textAttributes
        }
        let textAttributes = CMTextAttributes()
        textAttributes.blockQuoteAttributes = [
            NSFontAttributeName: UIFont.preferredFont(forTextStyle: .body),
            NSForegroundColorAttributeName: UIColor.lightMidGray,
            NSParagraphStyleAttributeName: {
                let paragraph = NSMutableParagraphStyle()
                paragraph.firstLineHeadIndent = 7
                paragraph.headIndent = 7
                paragraph.paragraphSpacingBefore = 4
                return paragraph
            }()
        ]
        textAttributes.textAttributes = [
            NSFontAttributeName: UIFont.preferredFont(forTextStyle: .body),
            NSForegroundColorAttributeName: UIColor.offBlack
        ]
        let linkColor = tableView?.tintColor ?? UIColor.blue
        textAttributes.linkAttributes = [
            NSUnderlineStyleAttributeName: NSUnderlineStyle.styleSingle.rawValue,
            NSForegroundColorAttributeName: linkColor,
            NSUnderlineColorAttributeName: linkColor
        ]
        cachedTextAttributes = textAttributes
        return textAttributes
    }
    
    // MARK: - Reachability
    
    func reachabilityChanged(_ notification: Notification) {
        animateCommentsUpdate()
    }
    
    // MARK: - Dynamic type 
    
    func preferredTextSizeChanged(_ notification: Notification) {
        cachedTextAttributes = nil
        CommentsCellModel.condensedHeight = nil
        for model in allComments {
            model.render = nil
            model.expandedHeight.removeAll()
        }
        tableView?.reloadData()
    }
}
