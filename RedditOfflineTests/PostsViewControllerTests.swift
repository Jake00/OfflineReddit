//
//  PostsViewControllerTests.swift
//  RedditOfflineTests
//
//  Created by Jake Bellamy on 13/05/17.
//  Copyright © 2017 Jake Bellamy. All rights reserved.
//

import XCTest
import CoreData
@testable import OfflineReddit

class PostsViewControllerTests: BaseTestCase {
    
    var postsViewController: PostsViewController!
    
    override func setUp() {
        super.setUp()
        postsViewController = PostsViewController.instantiateFromStoryboard()
        postsViewController.dataSource.provider = DataProvider(remote: remote, local: controller.context)
        postsViewController.dataSource.provider.reachability = reachability
        postsViewController.reachability = reachability
        _ = postsViewController.view
    }
    
    override func tearDown() {
        super.tearDown()
        postsViewController = nil
    }
    
    func fillDataSource() {
        let posts = try? controller.context.fetch(Post.fetchRequest() as NSFetchRequest<Post>)
        postsViewController.dataSource.rows = posts?.map(PostCellModel.init) ?? []
    }
    
    // MARK: - Tests
    
    func testThatItUpdatesChooseDownloadsButtonIsEnabled() {
        let isEnabled = { self.postsViewController.chooseDownloadsButton.isEnabled }
        
        // Disabled with no rows to select
        XCTAssertTrue(postsViewController.dataSource.rows.isEmpty, "No rows should have been fetched yet")
        postsViewController.updateChooseDownloadsButtonEnabled()
        XCTAssertFalse(isEnabled(), "Cannot choose posts to download with no rows available.")
        
        // Enabled with rows to select
        fillDataSource()
        postsViewController.updateChooseDownloadsButtonEnabled()
        XCTAssertTrue(isEnabled(), "Should allow downloading posts with rows available.")
        
        // Disabled after going offline
        reachability.isOnline = false
        postsViewController.updateChooseDownloadsButtonEnabled()
        XCTAssertFalse(isEnabled(), "Cannot download posts while offline")
        
        // Renabled after going back online
        reachability.isOnline = true
        postsViewController.updateChooseDownloadsButtonEnabled()
        XCTAssertTrue(isEnabled(), "Should allow downloading posts once back online.")
        
        let finishedPostsDownload = expectation(description: "Finished posts download")
        let indexPath = IndexPath(row: 0, section: 0)
        postsViewController.startPostsDownload(for: [indexPath]).continueWith { _ in
            // Enabled once downloading completes
            finishedPostsDownload.fulfill()
            XCTAssertTrue(isEnabled(), "Should allow downloading posts when previous download has completed.")
        }
        // Disabled once downloading an offline post
        XCTAssertFalse(isEnabled(), "Cannot allow downloading posts while already downloading")
        
        waitForExpectations(timeout: 5, handler: nil)
    }
    
    func testThatItUpdatesStartDownloadsButtonIsEnabled() {
        let isEnabled = { self.postsViewController.startDownloadsButton.isEnabled }
        
        fillDataSource()
        
        // Disabled while not editing (cannot select rows)
        postsViewController.setEditing(false, animated: false)
        XCTAssertFalse(isEnabled(), "Cannot start downloads when not in editing mode")
        
        // Disabled with no rows selected
        postsViewController.setEditing(true, animated: false)
        XCTAssertFalse(isEnabled(), "Cannot start downloads without selecting an item first")
        
        // Enabled with one row selected
        let indexPath = IndexPath(row: 0, section: 0)
        postsViewController.tableView.selectRow(at: indexPath, animated: false, scrollPosition: .none)
        postsViewController.tableView.delegate?.tableView?(postsViewController.tableView, didSelectRowAt: indexPath)
        XCTAssertTrue(isEnabled(), "Can start downloads once item has been selected")
        
        let finishedPostsDownload = expectation(description: "Finished posts download")
        postsViewController.startPostsDownload(for: [indexPath]).continueWith { _ in
            // Disabled once downloading completes
            finishedPostsDownload.fulfill()
            XCTAssertFalse(isEnabled(), "Cannot start downloads as table view is no longer editing.")
        }
        // Disabled after download starts
        XCTAssertFalse(isEnabled(), "Cannot start downloads whilst another download is in progress")
        
        waitForExpectations(timeout: 5, handler: nil)
    }
    
    func testThatItDownloadsPosts() {
        fillDataSource()
        let postsViewController = self.postsViewController!
        
        guard let (indexPath, post) = postsViewController.dataSource.rows.enumerated()
            .first(where: { !$1.post.comments.isEmpty })
            .map({ (IndexPath(row: $0, section: 0), $1.post) })
            else {
                XCTFail("Unable to find a downloadable post for testing")
                return
        }
        
        // Post starts not being available offline
        XCTAssertFalse(post.isAvailableOffline, "Post starts not available offline")
        
        let finishedPostsDownload = expectation(description: "Finished posts download")
        postsViewController.startPostsDownload(for: [indexPath]).continueWith { _ in
            finishedPostsDownload.fulfill()
            // `isSavingOffline` == false
            XCTAssertFalse(postsViewController.isSavingOffline, "Stops downloading on completion")
            
            // Downloaded posts reports being available offline
            XCTAssertTrue(post.isAvailableOffline, "Post should be available offline after downloading")
        }
        // `isSavingOffline` == true
        XCTAssertTrue(postsViewController.isSavingOffline, "Shows that it is downloading offline")
        
        waitForExpectations(timeout: 5, handler: nil)
    }
}
