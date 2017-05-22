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
    @IBOutlet var markAsReadButton: UIBarButtonItem!
    @IBOutlet var sortButton: UIBarButtonItem!
    
    let dataSource: CommentsDataSource
    let reachability: Reachability
    
    // MARK: - Init
    
    init(post: Post, provider: DataProvider) {
        self.dataSource = CommentsDataSource(post: post, provider: provider)
        self.reachability = provider.reachability
        super.init(nibName: String(describing: CommentsViewController.self), bundle: nil)
    }
    
    @available(*, unavailable, message: "init(post:coder:) is not available. Use init(provider:) instead.")
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) is not available. Use init(post:provider:) instead.")
    }
    
    // MARK: - View controller
    
    override func viewDidLoad() {
        super.viewDidLoad()
        dataSource.delegate = self
        dataSource.tableView = tableView
        tableView.dataSource = dataSource
        tableView.delegate = dataSource
        tableView.tableHeaderView = headerView
        tableView.tableFooterView = UIView()
        tableView.registerReusableNibCell(CommentsCell.self)
        tableView.registerReusableNibCell(MoreCommentsCell.self)
        subredditLabel.text = dataSource.post.subredditNamePrefixed
        authorTimeLabel.text = dataSource.post.authorTimeText
        titleLabel.text = dataSource.post.title
        selfLabel.text = dataSource.post.selfText
        isLoading = false
        toolbarItems = [
            markAsReadButton,
            UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil),
            sortButton
        ]
        markAsReadButton.isEnabled = !dataSource.post.isRead
        updateSortButtonTitle()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        if let selectedIndexPath = tableView.indexPathForSelectedRow {
            tableView.deselectRow(at: selectedIndexPath, animated: animated)
        }
        _ = dataSource.fetchCommentsIfNeeded().map(fetch)
        navigationController?.setToolbarHidden(false, animated: animated)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        navigationController?.setToolbarHidden(true, animated: animated)
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        let fittingSize = CGSize(width: tableView.frame.width, height: UILayoutFittingCompressedSize.height)
        headerView.frame.size.height = headerView.systemLayoutSizeFitting(fittingSize, withHorizontalFittingPriority: UILayoutPriorityRequired, verticalFittingPriority: UILayoutPriorityFittingSizeLevel).height
    }
    
    // MARK: - Loadable
    
    var isLoading = false {
        didSet {
            navigationItem.setRightBarButtonItems([isLoading ? loadingButton : expandCommentsButton], animated: true)
        }
    }
    
    // MARK: - Comments downloading
    
    var isSavingComments: Bool {
        return dataSource.downloader != nil
    }
    
    @discardableResult
    func startCommentsDownload() -> Task<Void> {
        let task = fetch(dataSource.startDownload(updating: tableView))
            .continueOnSuccessWith(.mainThread) { _ -> Void in
                self.navigationBarProgressView?.observedProgress = nil
                self.navigationBarProgressView?.isHidden = true
        }
        navigationBarProgressView?.isHidden = false
        navigationBarProgressView?.setProgress(0, animated: false)
        navigationBarProgressView?.observedProgress = dataSource.downloader?.progress
        return task
    }
    
    // MARK: - UI Actions
    
    @IBAction func expandCommentsButtonPressed(_ sender: UIBarButtonItem) {
        startCommentsDownload()
    }
    
    @IBAction func markAsReadButtonPressed(_ sender: UIBarButtonItem) {
        dataSource.post.isRead = true
        sender.isEnabled = false
    }
    
    @IBAction func sortButtonPressed(_ sender: UIBarButtonItem) {
        showSortSelectionSheet()
    }
    
    func showSortSelectionSheet() {
        let sheet = UIAlertController(title: SharedText.sortTitle, message: nil, preferredStyle: .actionSheet)
        for sort in Comment.Sort.all {
            sheet.addAction(UIAlertAction(title: sort.displayName, style: .default) { _ in
                self.dataSource.sort = sort
                self.tableView.reloadData()
                self.updateSortButtonTitle()
            })
        }
        present(sheet, animated: true, completion: nil)
    }
    
    // MARK: - UI Updates
    
    func updateSortButtonTitle() {
        sortButton.title = String.localizedStringWithFormat(SharedText.sortFormat, dataSource.sort.displayName)
    }
}

// MARK: - Data source delegate

extension CommentsViewController: CommentsDataSourceDelegate {
    
    var viewHorizontalMargins: CGFloat {
        return headerView.layoutMargins.left * 2
    }
    
    var viewFrameWidth: CGFloat {
        return view.frame.width
    }
    
    func isFetchingMoreComments(with task: Task<[Comment]>) {
        fetch(task)
    }
    
    func didUpdateAllComments(saved: Int64, toExpand: Int64) {
        expandCommentsButton.isEnabled = toExpand > 0 && reachability.isOnline
        commentsLabel.text = String.localizedStringWithFormat(
            NSLocalizedString("comments_saved_format", value: "%ld comments\n%ld / %ld saved", comment: "Format for number of comments and amount saved. eg. '50 comments\n30 / 40 saved'"),
            dataSource.post.commentsCount, saved, saved + toExpand)
    }
}
