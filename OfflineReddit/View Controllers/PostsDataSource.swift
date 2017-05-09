//
//  PostsDataSource.swift
//  OfflineReddit
//
//  Created by Jake Bellamy on 6/05/17.
//  Copyright © 2017 Jake Bellamy. All rights reserved.
//

import UIKit

class PostsDataSource: NSObject {
    
    var rows: [PostCellModel] = []
    var subreddits: [Subreddit] = [] {
        didSet { rows.removeAll() }
    }
    
    func post(at indexPath: IndexPath) -> Post {
        return rows[indexPath.row].post
    }
    
    // MARK: - Updating cells
    
    func updateAll(cell: PostCell?, row: PostCellModel) {
        update(cell: cell, post: row.post)
        update(cell: cell, state: row.state)
        update(cell: cell, isAvailableOffline: row.post.isAvailableOffline)
    }
    
    func update(cell: PostCell?, post: Post) {
        cell?.topLabel.text = post.subredditAuthorTimeText
        cell?.titleLabel.text = post.title
        cell?.bottomLabel.text = post.scoreCommentsText
    }
    
    func update(cell: PostCell?, state: PostCellModel.State) {
        cell?.containerLeading.constant = state == .normal ? 0 : PostCellModel.indentedWidth
        cell?.activityIndicator.setAnimating(state == .loading)
        cell?.checkedImageView.isHidden = state != .checked
    }
    
    func update(cell: PostCell?, isAvailableOffline: Bool) {
        cell?.offlineImageView.isHidden = !isAvailableOffline
    }
    
    func updateIsAvailableOffline(at indexPaths: [IndexPath], in tableView: UITableView) {
        for indexPath in indexPaths {
            update(
                cell: tableView.cellForRow(at: indexPath) as? PostCell,
                isAvailableOffline: post(at: indexPath).isAvailableOffline)
        }
    }
    
    // MARK: - Set models
    
    func setState(_ state: PostCellModel.State, at indexPath: IndexPath, in tableView: UITableView) {
        let cell = tableView.cellForRow(at: indexPath) as? PostCell
        rows[indexPath.row].state = state
        update(cell: cell, state: state)
    }
    
    func setState(_ state: PostCellModel.State, at indexPaths: [IndexPath], in tableView: UITableView) {
        for indexPath in indexPaths {
            setState(state, at: indexPath, in: tableView)
        }
    }
    
    func setState(_ state: PostCellModel.State, for post: Post, in tableView: UITableView) {
        if let (row, _) = rows.enumerated().first(where: { $0.1.post == post }) {
            setState(state, at: IndexPath(row: row, section: 0), in: tableView)
        }
    }
    
    func setAllStates(to state: PostCellModel.State, in tableView: UITableView) {
        let indexPaths = (0..<rows.count).map { IndexPath(row: $0, section: 0) }
        setState(state, at: indexPaths, in: tableView)
    }
    
    func setIsAvailableOffline(_ isAvailableOffline: Bool, at indexPath: IndexPath, in tableView: UITableView) {
        post(at: indexPath).isAvailableOffline = isAvailableOffline
        let cell = tableView.cellForRow(at: indexPath) as? PostCell
        update(cell: cell, isAvailableOffline: isAvailableOffline)
    }
}

// MARK: - Table view data source

extension PostsDataSource: UITableViewDataSource {

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return rows.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "Post", for: indexPath) as! PostCell
        updateAll(cell: cell, row: rows[indexPath.row])
        cell.setNeedsLayout()
        cell.layoutIfNeeded()
        return cell
    }
}
