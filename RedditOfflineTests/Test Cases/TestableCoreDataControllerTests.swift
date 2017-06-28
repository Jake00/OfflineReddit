//
//  TestableCoreDataControllerTests.swift
//  OfflineReddit
//
//  Created by Jake Bellamy on 19/05/17.
//  Copyright © 2017 Jake Bellamy. All rights reserved.
//

import XCTest
import CoreData
@testable import OfflineReddit

class TestableCoreDataControllerTests: BaseTestCase {
    
    func testThatItResetsTheContext() {
        guard let post = (try? controller.context.fetch(Post.fetchRequest() as NSFetchRequest<Post>))?.first else {
            XCTFail("The context has not imported models.")
            return
        }
        
        let before = post.isAvailableOffline
        post.isAvailableOffline = !post.isAvailableOffline
        
        _ = try? controller.context.save()
        controller.reset()
        
        // swiftlint:disable:next force_cast
        let newPost = controller.context.object(with: post.objectID) as! Post
        let after = newPost.isAvailableOffline
        
        XCTAssert(before == after, "The context has been reset to its fresh state.")
    }
}
