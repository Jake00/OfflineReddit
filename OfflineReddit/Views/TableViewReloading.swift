//
//  TableViewReloading.swift
//  OfflineReddit
//
//  Created by Jake Bellamy on 21/03/17.
//  Copyright © 2017 Jake Bellamy. All rights reserved.
//

import UIKit

extension UITableView {
    
    func reloadData(
        animated: Bool,
        old: Int = 0,
        new: Int,
        reloadingFrom: Int? = nil,
        animation: UITableViewRowAnimation = .fade,
        atomic: Bool = true,
        reloadingRows: ([IndexPath]) -> [IndexPath] = { $0 }
        ) {
        
        guard animated else { reloadData(); return }
        
        if atomic {
            beginUpdates()
        }
        if old > new {
            let indexPaths = (new..<old).map { IndexPath(row: $0, section: 0) }
            deleteRows(at: indexPaths, with: animation)
        } else if old < new {
            let indexPaths = (old..<new).map { IndexPath(row: $0, section: 0) }
            insertRows(at: indexPaths, with: animation)
        }
        if let reloadingFrom = reloadingFrom, reloadingFrom < min(old, new) {
            let indexPaths = reloadingRows(
                (reloadingFrom..<min(old, new)).map { IndexPath(row: $0, section: 0) })
            if !indexPaths.isEmpty {
                reloadRows(at: indexPaths, with: animation)
            }
        }
        if atomic {
            endUpdates()
        }
    }
}

extension Collection {
    
    subscript (safe index: Self.Index) -> Iterator.Element? {
        return (startIndex..<endIndex) ~= index ? self[index] : nil
    }
}
