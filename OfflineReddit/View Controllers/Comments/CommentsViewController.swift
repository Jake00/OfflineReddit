//
//  CommentsViewController.swift
//  OfflineReddit
//
//  Created by Jake Bellamy on 19/03/17.
//  Copyright © 2017 Jake Bellamy. All rights reserved.
//

import UIKit
import BoltsSwift
import CocoaMarkdown

class CommentsViewController: UIViewController, Loadable {
    
    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var headerView: UIView!
    @IBOutlet weak var subredditLabel: UILabel!
    @IBOutlet weak var authorTimeLabel: UILabel!
    @IBOutlet weak var commentsLabel: UILabel!
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var selfTextView: URLTextView!
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
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    // MARK: - View controller
    
    override func viewDidLoad() {
        super.viewDidLoad()
        dataSource.tableView = tableView
        dataSource.delegate = self
        dataSource.textViewDelegate = self
        selfTextView.delegate = self
        tableView.dataSource = dataSource
        tableView.delegate = dataSource
        tableView.tableHeaderView = headerView
        tableView.tableFooterView = UIView()
        tableView.registerReusableNibCell(CommentsCell.self)
        tableView.registerReusableNibCell(MoreCommentsCell.self)
        updateHeaderLabels()
        isLoading = false
        toolbarItems = [
            markAsReadButton,
            UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil),
            sortButton
        ]
        markAsReadButton.isEnabled = !dataSource.post.isRead
        updateSortButtonTitle()
        enableDynamicType()
        NotificationCenter.default.addObserver(self, selector: #selector(updateSelfText), name: .UIContentSizeCategoryDidChange, object: nil)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        dataSource.fetchCommentsIfNeeded()?.continueOnSuccessWith(.mainThread, continuation: updateHeaderLabels)
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        let fittingSize = CGSize(width: tableView.frame.width, height: UILayoutFittingCompressedSize.height)
        headerView.frame.size.height = headerView.systemLayoutSizeFitting(fittingSize, withHorizontalFittingPriority: UILayoutPriorityRequired, verticalFittingPriority: UILayoutPriorityFittingSizeLevel).height
    }
    
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        coordinator.animate(alongsideTransition: { _ in
            self.tableView.beginUpdates()
            self.tableView.endUpdates()
        }, completion: nil)
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
        let setRead: (Bool) -> () -> Void = { read in {
            self.dataSource.post.isRead = read
            sender.isEnabled = !read
            }}
        setRead(true)()
        showInfoToolbar(title: SharedText.readPost, undo: setRead(false))
    }
    
    @IBAction func sortButtonPressed(_ sender: UIBarButtonItem) {
        showSortSelectionSheet()
    }
    
    func showSortSelectionSheet() {
        let sheet = UIAlertController(title: SharedText.sortCommentsTitle, message: nil, preferredStyle: .actionSheet)
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
    
    func updateHeaderLabels() {
        subredditLabel.text = dataSource.post.subredditNamePrefixed
        authorTimeLabel.text = dataSource.post.authorTimeText
        titleLabel.text = dataSource.post.title
        updateSelfText()
    }
    
    func updateSelfText() {
        let render: CMAttributedStringRenderResult? = {
            guard let data = dataSource.post.selfText?.data(using: .utf8) else { return nil }
            return CMDocument(data: data, options: [])
                .attributedString(with: dataSource.textAttributes)
        }()
        selfTextView.attributedText = render?.result
        selfTextView.blockQuoteRanges = render?.blockQuoteRanges.map { $0.rangeValue } ?? []
        selfTextView.linkTextAttributes = dataSource.textAttributes.linkAttributes
        view.setNeedsLayout() // update headerView height via `viewDidLayoutSubviews`
    }
    
    func enableDynamicType() {
        subredditLabel.enableDynamicType(style: .footnote, weight: .semibold)
        authorTimeLabel.enableDynamicType(style: .footnote)
        commentsLabel.enableDynamicType(style: .footnote)
        titleLabel.enableDynamicType(style: .headline)
    }
    
    // MARK: - Navigation
    
    func showWebViewController(loading URL: URL) {
        navigationController?.pushViewController(WebViewController(initialURL: URL), animated: true)
    }
}

// MARK: - Data source delegate

extension CommentsViewController: CommentsDataSourceDelegate {
    
    func commentsDataSource(_ dataSource: CommentsDataSource, isFetchingWith task: Task<Void>) {
        fetch(task)
    }
    
    func commentsDataSource(_ dataSource: CommentsDataSource, didUpdateAllCommentsWith saved: Int64, _ toExpand: Int64) {
        expandCommentsButton.isEnabled = toExpand > 0 && reachability.isOnline
        commentsLabel.text = String.localizedStringWithFormat(
            NSLocalizedString("comments_saved_format", value: "%ld comments\n%ld / %ld saved", comment: "Format for number of comments and amount saved. eg. '50 comments\n30 / 40 saved'"),
            dataSource.post.commentsCount, saved, saved + toExpand)
    }
    
    func viewDimensionsForCommentsDataSource(_ dataSource: CommentsDataSource) -> (horizontalMargins: CGFloat, frameWidth: CGFloat) {
        return (headerView.layoutMargins.left * 2, view.frame.width)
    }
}

// MARK: - Text view delegate

extension CommentsViewController: UITextViewDelegate {
    
    func textView(_ textView: UITextView, shouldInteractWith URL: URL, in characterRange: NSRange) -> Bool {
        showWebViewController(loading: URL)
        return false
    }
}
