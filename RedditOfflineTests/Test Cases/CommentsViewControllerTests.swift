//
//  CommentsViewControllerTests.swift
//  OfflineReddit
//
//  Created by Jake Bellamy on 19/05/17.
//  Copyright © 2017 Jake Bellamy. All rights reserved.
//

import XCTest
import CoreData
@testable import OfflineReddit

class CommentsViewControllerTests: BaseTestCase {
    
    var commentsViewController: CommentsViewController!
    
    override func setUp() {
        super.setUp()
        let context = controller.newEmptyManagedObjectContext()
        controller.context = context
        remote.context = context
        remote.mapper.context = context
        controller.importPosts(to: context, including: .comments)

        
        let fetch = NSFetchRequest<Post>(entityName: String(describing: Post.self))
        fetch.sortDescriptors = [NSSortDescriptor(key: "commentsCount", ascending: false)]
        guard let post = (try? context.fetch(fetch))?.first else {
            fatalError("No post available for testing CommentsViewController")
        }
        
        commentsViewController = CommentsViewController(post: post, provider: provider)
        _ = commentsViewController.view // load view
        commentsViewController.dataSource.fetchCommentsIfNeeded()
    }
    
    override func tearDown() {
        commentsViewController = nil
        super.tearDown()
    }
    
    // MARK: - Tests
    
    func testThatItDownloadsComments() {
        let commentsViewController = self.commentsViewController!
        let post = commentsViewController.dataSource.post
        let oldMoreCommentsCount = post.allMoreComments(sortedBy: .top).count
        let finishedCommentsDownload = expectation(description: "Finished comments download")
        commentsViewController.startCommentsDownload().continueWith { _ in
            finishedCommentsDownload.fulfill()
            // `isSavingComments` == false
            XCTAssertFalse(commentsViewController.isSavingComments, "Stops downloading on completion")
            
            // There are less 'more comments' to expand
            let newMoreCommentsCount = post.allMoreComments(sortedBy: .top).count
            XCTAssert(newMoreCommentsCount < oldMoreCommentsCount, "Post should have less 'more comments' to expand")
        }
        // `isSavingComments` == true
        XCTAssertTrue(commentsViewController.isSavingComments, "Shows that it is downloading comments")
        
        waitForExpectations(timeout: 5, handler: nil)
    }
}
