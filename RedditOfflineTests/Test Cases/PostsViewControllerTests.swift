//
//  PostsViewControllerTests.swift
//  RedditOfflineTests
//
//  Created by Jake Bellamy on 13/05/17.
//  Copyright © 2017 Jake Bellamy. All rights reserved.
//

import XCTest
import CoreData
import BoltsSwift
@testable import OfflineReddit

private class TestingPostsViewController: PostsViewController {
    
    var didCallReachabilityChanged = false
    
    override func reachabilityChanged(_ notification: Notification) {
        didCallReachabilityChanged = true
        super.reachabilityChanged(notification)
    }
}

private class TestingPostsDataSource: PostsDataSource {
    
    var allowFetchingPosts = true
    var didCallFetchNextPageOrReloadIfOffline = false
    
    override func fetchNextPageOrReloadIfOffline() -> Task<[Post]> {
        didCallFetchNextPageOrReloadIfOffline = true
        return allowFetchingPosts
            ? super.fetchNextPageOrReloadIfOffline()
            : Task<[Post]>([])
    }
    
    override func fetchInitial() -> Task<Void> {
        return Task(()) // Stubbed out, we manually fill the data source for greater testing control
    }
}

class PostsViewControllerTests: BaseTestCase {
    
    fileprivate var postsViewController: TestingPostsViewController!
    fileprivate var dataSource: TestingPostsDataSource!
    
    override func setUp() {
        super.setUp()
        dataSource = TestingPostsDataSource(provider: provider)
        postsViewController = TestingPostsViewController(dataSource: dataSource)
        _ = postsViewController.view // load view
    }
    
    override func tearDown() {
        super.tearDown()
        postsViewController = nil
    }
    
    func fillDataSource() {
        let fetch = NSFetchRequest<Post>(entityName: String(describing: Post.self))
        let posts: [Post]? = try? controller.context.fetch(fetch)
        postsViewController.dataSource.allRows = Set(posts?.map(PostCellModel.init) ?? [])
        postsViewController.dataSource.updateRows()
        postsViewController.tableView.reloadData()
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
        postsViewController.startPostsDownload(for: [indexPath], additional: 0).continueWith { _ in
            // Enabled once downloading completes
            finishedPostsDownload.fulfill()
            XCTAssertTrue(isEnabled(), "Should allow downloading posts when previous download has completed.")
        }
        // Disabled once downloading an offline post
        XCTAssertFalse(isEnabled(), "Cannot allow downloading posts while already downloading")
        
        waitForExpectations(timeout: 5, handler: nil)
    }
    
    func testThatItUpdatesStartDownloadsButtonIsEnabled() {
        let isEnabled = { self.postsViewController.downloadPostsSaveButton.isEnabled }
        
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
        postsViewController.startPostsDownload(for: [indexPath], additional: 0).continueWith { _ in
            // Disabled once downloading completes
            finishedPostsDownload.fulfill()
            XCTAssertFalse(isEnabled(), "Cannot start downloads as table view is no longer editing.")
        }
        // Disabled after download starts
        XCTAssertFalse(isEnabled(), "Cannot start downloads whilst another download is in progress")
        
        waitForExpectations(timeout: 5, handler: nil)
    }
    
    func testThatItReceivesReachabilityNotifications() {
        XCTAssertFalse(postsViewController.didCallReachabilityChanged, "No notifications have been sent yet")
        NotificationCenter.default.post(name: .ReachabilityChanged, object: nil)
        XCTAssertTrue(postsViewController.didCallReachabilityChanged, "Controller should have received the notification")
    }
    
    func testThatItReactsToReachabilityChanges() {
        dataSource.allowFetchingPosts = false
        dataSource.didCallFetchNextPageOrReloadIfOffline = false
        
        fillDataSource()
        reachability.isOnline = true
        NotificationCenter.default.post(name: .ReachabilityChanged, object: nil)
        
        XCTAssertTrue(postsViewController.loadMoreButton.isEnabled, "Can load more when online")
        XCTAssertTrue(dataSource.didCallFetchNextPageOrReloadIfOffline, "New posts are automatically fetched when going online")
        
        dataSource.didCallFetchNextPageOrReloadIfOffline = false
        postsViewController.setEditing(true, animated: false)
        fillDataSource()
        reachability.isOnline = false
        NotificationCenter.default.post(name: .ReachabilityChanged, object: nil)
        
        XCTAssertFalse(postsViewController.isEditing, "Editing disabled when going offline")
        XCTAssertFalse(postsViewController.loadMoreButton.isEnabled, "Cannot load more when offline")
        XCTAssertTrue(postsViewController.dataSource.rows.isEmpty, "Rows were emptied when going offline")
        XCTAssertTrue(dataSource.didCallFetchNextPageOrReloadIfOffline, "Offline posts are automatically fetched when going online")
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
        
        XCTAssertFalse(post.isAvailableOffline, "Post starts not available offline")
        
        let finishedPostsDownload = expectation(description: "Finished posts download")
        postsViewController.startPostsDownload(for: [indexPath], additional: 0).continueWith { _ in
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
