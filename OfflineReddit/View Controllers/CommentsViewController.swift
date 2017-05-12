//
//  CommentsViewController.swift
//  OfflineReddit
//
//  Created by Jake Bellamy on 19/03/17.
//  Copyright © 2017 Jake Bellamy. All rights reserved.
//

import UIKit
import BoltsSwift

class CommentsViewController: UIViewController, Loadable {
    
    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var headerView: UIView!
    @IBOutlet weak var subredditLabel: UILabel!
    @IBOutlet weak var authorTimeLabel: UILabel!
    @IBOutlet weak var commentsLabel: UILabel!
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var selfLabel: UILabel!
    @IBOutlet var loadingButton: UIBarButtonItem!
    @IBOutlet var expandCommentsButton: UIBarButtonItem!
    
    let dataSource = CommentsDataSource()
    
    var isLoading = false {
        didSet {
            navigationItem.setRightBarButtonItems([isLoading ? loadingButton : expandCommentsButton], animated: true)
        }
    }
    
    // MARK: - View controller
    
    override func viewDidLoad() {
        super.viewDidLoad()
        dataSource.delegate = self
        tableView.dataSource = dataSource
        tableView.delegate = dataSource
        subredditLabel.text = dataSource.post?.subredditNamePrefixed
        authorTimeLabel.text = dataSource.post?.authorTimeText
        titleLabel.text = dataSource.post?.title
        selfLabel.text = dataSource.post?.selfText
        isLoading = false
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        if let selectedIndexPath = tableView.indexPathForSelectedRow {
            tableView.deselectRow(at: selectedIndexPath, animated: animated)
        }
        dataSource.fetchCommentsIfNeeded(updating: tableView).map(fetch)
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        let fittingSize = CGSize(width: tableView.frame.width, height: UILayoutFittingCompressedSize.height)
        headerView.frame.size.height = headerView.systemLayoutSizeFitting(fittingSize, withHorizontalFittingPriority: UILayoutPriorityRequired, verticalFittingPriority: UILayoutPriorityFittingSizeLevel).height
    }
    
    // MARK: -
    
    func startCommentsDownload() {
        fetch(dataSource.startDownload(updating: tableView))
            .continueOnSuccessWith(.mainThread) { _ -> Void in
                self.navigationBarProgressView?.observedProgress = nil
                self.navigationBarProgressView?.isHidden = true
        }
        navigationBarProgressView?.isHidden = false
        navigationBarProgressView?.setProgress(0, animated: false)
        navigationBarProgressView?.observedProgress = dataSource.downloader?.progress
    }
    
    @IBAction func expandCommentsButtonPressed(_ sender: UIBarButtonItem) {
        startCommentsDownload()
    }
}

extension CommentsViewController: CommentsDataSourceDelegate {
    
    var viewHorizontalMargins: CGFloat {
        return headerView.readableContentGuide.layoutFrame.minX * 2
    }
    
    var viewFrameWidth: CGFloat {
        return view.frame.width
    }
    
    func isFetchingMoreComments(with task: Task<[Comment]>) {
        fetch(task)
    }
    
    func didUpdateAllComments(saved: Int64, toExpand: Int64) {
        expandCommentsButton.isEnabled = toExpand > 0 && isOnline
        commentsLabel.text = String.localizedStringWithFormat(
            NSLocalizedString("comments_saved_format", value: "%ld comments\n%ld / %ld saved", comment: "Format for number of comments and amount saved. eg. '50 comments\n30 / 40 saved'"),
            dataSource.post?.commentsCount ?? 0, saved, saved + toExpand)
    }
}
