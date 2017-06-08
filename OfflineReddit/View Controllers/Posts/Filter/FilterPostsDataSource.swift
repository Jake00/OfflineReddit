//
//  FilterPostsDataSource.swift
//  OfflineReddit
//
//  Created by Jake Bellamy on 27/05/17.
//  Copyright © 2017 Jake Bellamy. All rights reserved.
//

import UIKit

class FilterPostsDataSource: NSObject {
    
    enum Section: Int {
        case readStatus
        case offlineStatus
        case sort
    }
    
    weak var tableView: UITableView?
    
    // MARK: - Init
    
    let reachability: Reachability
    
    init(reachability: Reachability) {
        self.reachability = reachability
        super.init()
        NotificationCenter.default.addObserver(self, selector: #selector(reachabilityChanged(_:)), name: .ReachabilityChanged, object: nil)
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    // MARK: - Sorts
    
    let sorts = Post.Sort.all
    let sortPeriods: [Post.SortPeriod] = Post.SortPeriod.all.reversed()
    let readStatusFilters: [Post.FilterOption] = [
        Post.FilterOption(value: .read, displayName: SharedText.read),
        Post.FilterOption(value: .notRead, displayName: SharedText.notRead),
        Post.FilterOption(value: [.read, .notRead], displayName: SharedText.both)
    ]
    let offlineStatusFilters: [Post.FilterOption] = [
        Post.FilterOption(value: .offline, displayName: SharedText.savedOffline),
        Post.FilterOption(value: .online, displayName: SharedText.onlineOnly),
        Post.FilterOption(value: [.offline, .online], displayName: SharedText.both)
    ]
    var selected = Defaults.postsSortFilter {
        didSet {
            if isFirstSelectionSet {
                isFirstSelectionSet = false
                initialSelected = selected
            }
        }
    }
    
    // MARK: - Changes
    
    private var initialSelected = Defaults.postsSortFilter
    private var isFirstSelectionSet = true
    
    var hasChanges: Bool {
        return selected != initialSelected
    }
    
    // MARK: - UI actions
    
    fileprivate dynamic func readStatusSelectionChanged(_ sender: UISegmentedControl) {
        let new = readStatusFilters[sender.selectedSegmentIndex].value
        selected.filter = selected.filter.intersection([.offline, .online]).union(new)
    }
    
    fileprivate dynamic func offlineStatusSelectionChanged(_ sender: UISegmentedControl) {
        let new = offlineStatusFilters[sender.selectedSegmentIndex].value
        selected.filter = selected.filter.intersection([.read, .notRead]).union(new)
    }
    
    fileprivate dynamic func sortPeriodSelectionChanged(_ sender: LabelSliderControl) {
        if let period = sender.selectedDiscreteValue as? Post.SortPeriod {
            selected.period = period
        }
    }
    
    // MARK: - Reachability
    
    func reachabilityChanged(_ notification: Notification) {
        if reachability.isOffline {
            selected.filter.remove(.online)
        }
        tableView?.reloadSections(IndexSet(integer: Section.offlineStatus.rawValue), with: .fade)
    }
}

// MARK: - Table view data source

extension FilterPostsDataSource: UITableViewDataSource {
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return 3
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        guard let section = Section(rawValue: section) else { return 0 }
        switch section {
        case .readStatus, .offlineStatus: return 1
        case .sort: return sorts.count
        }
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let section = Section(rawValue: indexPath.section) else {
            fatalError("FilterPostsDataSource is incorrectly configured: Attempted to create cell at indexPath (section \(indexPath.section), row \(indexPath.row))")
        }
        switch section {
        case .readStatus, .offlineStatus:
            return configureFilterCell(
                tableView.dequeueReusableCell(for: indexPath),
                isReadStatus: section == .readStatus)
        case .sort:
            return configureSortCell(
                tableView.dequeueReusableCell(for: indexPath),
                sort: sorts[indexPath.row])
        }
    }
    
    func configureFilterCell(_ cell: FilterPostsSegmentedControlCell, isReadStatus: Bool) -> FilterPostsSegmentedControlCell {
        let filters = isReadStatus ? readStatusFilters : offlineStatusFilters
        cell.control.items = filters.map { $0.displayName }
        cell.control.setTitleTextAttributes([NSFontAttributeName: UIFont.preferredFont(forTextStyle: .caption1)], for: .normal)
        cell.control.removeTarget(self, action: nil, for: .touchUpInside)
        cell.control.addTarget(self, action: isReadStatus
            ? #selector(readStatusSelectionChanged(_:))
            : #selector(offlineStatusSelectionChanged(_:)), for: .valueChanged)
        cell.control.isEnabled = isReadStatus || reachability.isOnline
        let last = filters.enumerated().filter { selected.filter.contains($1.value) }.last
        if let (index, _) = last {
            cell.control.selectedSegmentIndex = index
        }
        return cell
    }
    
    func configureSortCell(_ cell: FilterPostsSortCell, sort: Post.Sort) -> FilterPostsSortCell {
        cell.titleLabel.font = UIFont.preferredFont(forTextStyle: .body)
        cell.titleLabel.text = sort.displayName
        cell.canExpand = sort.includesTimePeriods
        cell.isChecked = sort == selected.sort
        cell.control?.discreteValues = sortPeriods
        cell.control?.selectedDiscreteValue = selected.period
        if cell.control?.allTargets.contains(self) == false {
            cell.control?.addTarget(self, action: #selector(sortPeriodSelectionChanged(_:)), for: .valueChanged)
        }
        return cell
    }
}

// MARK: - Table view delegate

extension FilterPostsDataSource: UITableViewDelegate {
    
    func tableView(_ tableView: UITableView, shouldHighlightRowAt indexPath: IndexPath) -> Bool {
        return indexPath.section == Section.sort.rawValue
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        guard selected.sort != sorts[indexPath.row] else { return }
        let selectedCell = tableView.cellForRow(at: indexPath) as? FilterPostsSortCell
        selected.sort = sorts[indexPath.row]
        selected.period = selectedCell?.control?.selectedDiscreteValue as? Post.SortPeriod
        UIView.animate(withDuration: 0.2) {
            for cell in tableView.visibleCells.flatMap({ $0 as? FilterPostsSortCell }) {
                cell.isChecked = false
            }
        }
        UIView.animate(withDuration: 0.4) {
            selectedCell?.isChecked = true
        }
        tableView.beginUpdates()
        tableView.endUpdates()
    }
    
    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        guard let section = Section(rawValue: section) else { return nil }
        switch section {
        case .readStatus: return SharedText.readStatus
        case .offlineStatus: return SharedText.offlineStatus
        case .sort: return SharedText.sortPostsTitle
        }
    }
    
    func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        return section != Section.offlineStatus.rawValue || reachability.isOnline ? nil : SharedText.onlineFilterDisabledReason
    }
}

extension Post.SortPeriod: LabelSliderDisplayable { }
