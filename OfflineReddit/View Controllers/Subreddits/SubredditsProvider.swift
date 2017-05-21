//
//  SubredditsProvider.swift
//  OfflineReddit
//
//  Created by Jake Bellamy on 21/05/17.
//  Copyright © 2017 Jake Bellamy. All rights reserved.
//

import CoreData
import BoltsSwift

final class SubredditsProvider {
    
    let local: NSManagedObjectContext
    
    init(provider: DataProvider) {
        self.local = provider.local
    }
    
    func getAllSubreddits() -> Task<[Subreddit]> {
        let request: NSFetchRequest<Subreddit> = Subreddit.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(key: "name", ascending: true, selector: #selector(NSString.caseInsensitiveCompare(_:)))]
        return local.fetch(request)
    }
    
    func getAllSelectedSubreddits() -> Task<[Subreddit]> {
        let request = Subreddit.fetchRequest(predicate: NSPredicate(format: "isSelected == YES"))
        return local.fetch(request)
    }
}
