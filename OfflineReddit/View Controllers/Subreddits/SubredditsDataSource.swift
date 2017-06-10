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
    
    struct SubredditSection: Comparable {
        let contentType: Subreddit.ContentType
        var subreddits: [Subreddit]
        
        static func == (lhs: SubredditSection, rhs: SubredditSection) -> Bool {
            return lhs.contentType == rhs.contentType
        }
        
        static func < (lhs: SubredditSection, rhs: SubredditSection) -> Bool {
            return lhs.contentType.rawValue < rhs.contentType.rawValue
        }
    }
    
    weak var tableView: UITableView?
    
    var sections: [SubredditSection] = []
    
    var subreddits: [Subreddit] {
        return sections.flatMap { $0.subreddits }
    }
    
    func insertSubreddit(named subredditName: String) {
        let section = sections.index { $0.contentType == .unknown }
        let indexPath = section.map { IndexPath(row: sections[$0].subreddits.endIndex, section: $0) }
        let subreddit = Subreddit.create(in: provider.local, name: subredditName)
        subreddit.isSelected = true
        
        if let indexPath = indexPath {
            sections[indexPath.section].subreddits.append(subreddit)
            tableView?.insertRows(at: [indexPath], with: .fade)
        } else {
            sections.append(SubredditSection(contentType: .unknown, subreddits: [subreddit]))
            tableView?.insertSections(IndexSet(integer: sections.endIndex - 1), with: .fade)
        }
    }
    
    func setSections(subreddits: [Subreddit]) {
        var sections: [Subreddit.ContentType: [Subreddit]] = [:]
        for subreddit in subreddits {
            if var sectionSubreddits = sections[subreddit.contentType] {
                sectionSubreddits.append(subreddit)
                sections[subreddit.contentType] = sectionSubreddits
            } else {
                sections[subreddit.contentType] = [subreddit]
            }
        }
        self.sections = sections.map(SubredditSection.init).sorted()
    }
    
    @discardableResult
    func fillSubreddits(insertingDefaults: Bool = true) -> Task<[Subreddit]> {
        return provider.getAllSubreddits()
            .continueOnSuccessWith(.immediate) { subreddits -> [Subreddit] in
                var subreddits = subreddits
                if subreddits.isEmpty, insertingDefaults {
                    subreddits = Subreddit.insertDefaults(into: self.provider.local)
                }
                self.setSections(subreddits: subreddits)
                self.tableView?.reloadData()
                return subreddits
        }
    }
}

// MARK: - Table view data source

extension SubredditsDataSource: UITableViewDataSource {
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return sections.count
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return sections[section].subreddits.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell: SubredditCell = tableView.dequeueReusableCell(for: indexPath)
        let subreddit = sections[indexPath.section].subreddits[indexPath.row]
        cell.textLabel?.text = subreddit.name
        cell.textLabel?.font = .preferredFont(forTextStyle: .body)
        cell.isChecked = subreddit.isSelected
        return cell
    }
    
    func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCellEditingStyle, forRowAt indexPath: IndexPath) {
        guard editingStyle == .delete else { return }
        provider.local.delete(sections[indexPath.section].subreddits.remove(at: indexPath.row))
        if sections[indexPath.section].subreddits.isEmpty {
            sections.remove(at: indexPath.section)
            tableView.deleteSections(IndexSet(integer: indexPath.section), with: .fade)
        } else {
            tableView.deleteRows(at: [indexPath], with: .fade)
        }
    }
}

// MARK: - Table view delegate

extension SubredditsDataSource: UITableViewDelegate {
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let subreddit = sections[indexPath.section].subreddits[indexPath.row]
        subreddit.isSelected = !subreddit.isSelected
        (tableView.cellForRow(at: indexPath) as? SubredditCell)?.isChecked = subreddit.isSelected
    }
    
    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return sections[section].contentType.displayName
    }
}
