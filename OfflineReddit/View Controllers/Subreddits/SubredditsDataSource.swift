//
//  SubredditsDataSource.swift
//  OfflineReddit
//
//  Created by Jake Bellamy on 21/05/17.
//  Copyright © 2017 Jake Bellamy. All rights reserved.
//

import UIKit
import BoltsSwift

class SubredditsDataSource: NSObject {
    
    // MARK: - Init
    
    let provider: SubredditsProvider
    
    init(provider: DataProvider) {
        self.provider = SubredditsProvider(provider: provider)
    }
    
    // MARK: - 
    
    weak var tableView: UITableView?
    
    var subreddits: [Subreddit] = []
    
    func insertSubreddit(named subredditName: String) {
        let indexPath = IndexPath(row: subreddits.endIndex, section: 0)
        let subreddit = Subreddit.create(in: provider.local, name: subredditName)
        subreddit.isSelected = true
        subreddits.append(subreddit)
        tableView?.insertRows(at: [indexPath], with: .automatic)
    }
    
    @discardableResult
    func fillSubreddits(insertingDefaults: Bool = true) -> Task<[Subreddit]> {
        return provider.getAllSubreddits()
            .continueOnSuccessWith(.immediate) { subreddits -> [Subreddit] in
                var subreddits = subreddits
                if subreddits.isEmpty, insertingDefaults {
                    subreddits = Subreddit.insertDefaults(into: self.provider.local)
                }
                self.subreddits = subreddits
                self.tableView?.reloadData()
                return subreddits
        }
    }
}

// MARK: - Table view data source

extension SubredditsDataSource: UITableViewDataSource {
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return subreddits.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell: SubredditCell = tableView.dequeueReusableCell(for: indexPath)
        let subreddit = subreddits[indexPath.row]
        cell.textLabel?.text = subreddit.name
        cell.isChecked = subreddit.isSelected
        return cell
    }
    
    func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCellEditingStyle, forRowAt indexPath: IndexPath) {
        guard editingStyle == .delete else { return }
        provider.local.delete(subreddits.remove(at: indexPath.row))
        tableView.deleteRows(at: [indexPath], with: .automatic)
    }
}

// MARK: - Table view delegate

extension SubredditsDataSource: UITableViewDelegate {
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let subreddit = subreddits[indexPath.row]
        subreddit.isSelected = !subreddit.isSelected
        (tableView.cellForRow(at: indexPath) as? SubredditCell)?.isChecked = subreddit.isSelected
    }
}
