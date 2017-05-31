//
//  FilterPostsViewController.swift
//  OfflineReddit
//
//  Created by Jake Bellamy on 26/05/17.
//  Copyright © 2017 Jake Bellamy. All rights reserved.
//

import UIKit

class FilterPostsViewController: UIViewController {
    
    @IBOutlet var tableView: UITableView!
    
    let dataSource = FilterPostsDataSource()
    
    var didUpdate: ((Post.SortFilter) -> Void)?
    
    // MARK: - View controller
    
    override func viewDidLoad() {
        super.viewDidLoad()
        title = NSLocalizedString("filter_posts", value: "Filter posts", comment: "Filter posts title")
        tableView.rowHeight = UITableViewAutomaticDimension
        tableView.estimatedRowHeight = 44
        tableView.dataSource = dataSource
        tableView.delegate = dataSource
        tableView.registerReusableCell(FilterPostsSegmentedControlCell.self)
        tableView.registerReusableCell(FilterPostsSortCell.self)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        if dataSource.hasChanges {
            didUpdate?(dataSource.selected)
        }
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        didUpdate = nil
    }
}
