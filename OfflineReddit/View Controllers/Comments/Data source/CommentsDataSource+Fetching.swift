//
//  CommentsDataSource+Fetching.swift
//  OfflineReddit
//
//  Created by Jake Bellamy on 29/06/17.
//  Copyright © 2017 Jake Bellamy. All rights reserved.
//

import UIKit
import BoltsSwift

extension CommentsDataSource {
    
    // MARK: - Fetching
    
    func fetch<T>(_ task: Task<T>) -> Task<T> {
        delegate?.commentsDataSource(self, isFetchingWith: task.asVoid())
        return task
    }
    
    @discardableResult
    func fetchCommentsIfNeeded() -> Task<Void>? {
        if allComments.isEmpty {
            updateComments()
        }
        if allComments.isEmpty {
            return fetchComments()
        }
        return nil
    }
    
    func fetchComments() -> Task<Void> {
        return fetch(provider.getComments(for: post, sortedBy: sort)
            .continueOnSuccessWith(.mainThread) { _ in
                self.animateCommentsUpdate(fromSuccessfulFetch: true)
                self.provider.local.trySave()
        })
    }
    
    @discardableResult
    func fetchMoreComments(using more: MoreComments) -> Task<[Comment]> {
        return fetch(provider.getMoreComments(using: [more], post: post, sortedBy: sort)
            .continueWithTask(.mainThread) {
                self.didFetchMoreComments(more, task: $0)
        })
    }
    
    private func didFetchMoreComments(
        _ more: MoreComments,
        task: Task<[Comment]>
        ) -> Task<[Comment]> {
        
        loadingCells.remove(more)
        if task.error == nil {
            self.animateCommentsUpdate()
        } else {
            func indexPath(of more: MoreComments) -> IndexPath? {
                return comments.index(where: { $0.comment == more })
                    .map { IndexPath(row: $0, section: 0) }
            }
            let cell = indexPath(of: more).flatMap {
                tableView?.cellForRow(at: $0) as? MoreCommentsCell
            }
            updateMoreCell(cell, more)
        }
        return task
    }
    
    // MARK: - Offline saving
    
    @discardableResult
    func startDownload(updating tableView: UITableView) -> Task<Void> {
        
        let downloader = CommentsDownloader(
            post: post,
            comments: allComments.flatMap { $0.comment.other },
            remote: provider.remote,
            sort: sort)
        
        self.downloader = downloader
        
        return downloader.start().continueWithTask(.mainThread) {
            self.downloader = nil
            self.updateComments()
            tableView.reloadData()
            self.provider.local.trySave()
            return $0
        }
    }
}
