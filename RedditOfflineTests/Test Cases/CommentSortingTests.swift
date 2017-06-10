//
//  CommentSortingTests.swift
//  OfflineReddit
//
//  Created by Jake Bellamy on 10/06/17.
//  Copyright © 2017 Jake Bellamy. All rights reserved.
//

import XCTest
import CoreData
@testable import OfflineReddit

class CommentSortingTests: BaseTestCase {
    
    let postId = "t3_6gdfb9"
    var post: Post!
    
    override func setUp() {
        super.setUp()
        let request = Post.fetchRequest(predicate: NSPredicate(format: "id == %@", postId))
        request.relationshipKeyPathsForPrefetching = ["comments"]
        post = (try? controller.context.fetch(request))?.first
        assert(post != nil, "No post with id \(postId)")
    }
    
    override func tearDown() {
        super.tearDown()
        post = nil
    }
    
    // MARK: - Tests
    
    func testThatItSortsCorrectlyWithMoreCommentsIncluded() {
        for sort in Comment.Sort.all {
            
            let onlyCommentsSort = post.displayComments
                .flatMap { $0.first }
                .sorted(by: sort)
            
            let moreCommentsExcluded = post.displayComments
                .filter { $0.first != nil }
                .sorted(by: sort)
                .flatMap { $0.first }
            
            let moreCommentsIncluded = post.displayComments
                .sorted(by: sort)
                .flatMap { $0.first }
            
            XCTAssertEqual(onlyCommentsSort, moreCommentsExcluded, "\nSort \(sort) must match -- \(firstMismatchDiscription(between: onlyCommentsSort, moreCommentsExcluded))")
            
            XCTAssertEqual(onlyCommentsSort, moreCommentsIncluded, "\nSort \(sort) must match -- \(firstMismatchDiscription(between: onlyCommentsSort, moreCommentsIncluded))")
            
            XCTAssertEqual(moreCommentsExcluded, moreCommentsIncluded, "\nSort \(sort) must match -- \(firstMismatchDiscription(between: moreCommentsExcluded, moreCommentsIncluded))")
        }
    }
}

private func firstMismatchDiscription<T: Equatable>(between first: [T], _ second: [T]) -> String {
    for (index, element) in zip(first, second).enumerated() where element.0 != element.1 {
        return "Index \(index): '\(element.0)' != '\(element.1)'"
    }
    if first.endIndex > second.endIndex {
        return "First contains extra elements: '\(first[second.endIndex])'"
    } else if first.endIndex < second.endIndex {
        return "Second contains extra elements: '\(second[first.endIndex])'"
    }
    return "Elements equal"
}
