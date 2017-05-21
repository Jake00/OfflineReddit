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
        commentsViewController = CommentsViewController()
        commentsViewController.dataSource.provider = DataProvider(remote: remote, local: controller.context)
        commentsViewController.dataSource.provider.reachability = reachability
        commentsViewController.reachability = reachability
        _ = commentsViewController.view // load view
    }
    
    override func tearDown() {
        commentsViewController = nil
        super.tearDown()
    }
    
    @discardableResult
    func fillDataSource(context: NSManagedObjectContext) -> Post? {
        let fetch = NSFetchRequest<Post>(entityName: String(describing: Post.self))
        fetch.sortDescriptors = [NSSortDescriptor(key: "commentsCount", ascending: false)]
        let post = (try? context.fetch(fetch))?.first
        commentsViewController.dataSource.post = post
        commentsViewController.dataSource.fetchCommentsIfNeeded()
        return post
    }
    
    // MARK: - Tests
    
    func testThatItDownloadsComments() {
        let context = controller.newEmptyManagedObjectContext()
        remote.context = context
        remote.mapper.context = context
        controller.importPosts(to: context, including: .comments)
        
        guard let post = fillDataSource(context: context) else {
            XCTFail("No post to download comments for")
            return
        }
        
        let commentsViewController = self.commentsViewController!
        let oldMoreCommentsCount = post.allMoreComments.count
        let finishedCommentsDownload = expectation(description: "Finished comments download")
        commentsViewController.startCommentsDownload().continueWith { _ in
            finishedCommentsDownload.fulfill()
            // `isSavingComments` == false
            XCTAssertFalse(commentsViewController.isSavingComments, "Stops downloading on completion")
            
            // There are less 'more comments' to expand
            let newMoreCommentsCount = post.allMoreComments.count
            XCTAssert(newMoreCommentsCount < oldMoreCommentsCount, "Post should have less 'more comments' to expand")
        }
        // `isSavingComments` == true
        XCTAssertTrue(commentsViewController.isSavingComments, "Shows that it is downloading comments")
        
        waitForExpectations(timeout: 5, handler: nil)
    }
}
