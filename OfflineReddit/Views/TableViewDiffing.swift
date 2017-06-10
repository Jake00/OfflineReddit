//
//  TableViewDiffing.swift
//  OfflineReddit
//
//  Created by Jake Bellamy on 31/05/17.
//  Copyright © 2017 Jake Bellamy. All rights reserved.
//

import UIKit
import Dwifft

extension UITableView {
    
    func reload<T: Equatable>(
        old: [T],
        new: [T],
        section: Int = 0,
        numberOfEmptyCells: Int = 0
        ) {
        var deleting: [Int] = []
        var inserting: [Int] = []
        if old.isEmpty, numberOfEmptyCells > 0 {
            (0..<numberOfEmptyCells).forEach { deleting.append($0) }
        }
        for diff in Dwifft.diff(old, new) {
            switch diff {
            case .insert(let index, _): inserting.append(index)
            case .delete(let index, _): deleting.append(index)
            }
        }
        beginUpdates()
        deleteRows(at: deleting.map { IndexPath(row: $0, section: section) }, with: .fade)
        insertRows(at: inserting.map { IndexPath(row: $0, section: section) }, with: .fade)
        endUpdates()
    }
    
    func reload<T: Equatable>(
        section: Int = 0,
        get: () -> [T],
        update: () -> Void
        ) {
        let old = get()
        let numberOfEmptyCells = dataSource?.tableView(self, numberOfRowsInSection: section) ?? 0
        update()
        let new = get()
        reload(old: old, new: new, numberOfEmptyCells: numberOfEmptyCells)
    }
}
