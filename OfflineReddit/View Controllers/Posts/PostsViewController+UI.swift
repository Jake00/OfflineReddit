//
//  PostsViewController+UI.swift
//  OfflineReddit
//
//  Created by Jake Bellamy on 29/06/17.
//  Copyright © 2017 Jake Bellamy. All rights reserved.
//

import UIKit
import BoltsSwift

extension PostsViewController {
    
    // MARK: - Updating
    
    func updateFooterView() {
        let hideHints = !dataSource.subreddits.isEmpty
        hintLabel.isHidden = hideHints
        hintImage.isHidden = hideHints
        loadMoreButton.isHidden = !hideHints
        loadMoreButton.isEnabled = reachability.isOnline
        loadMoreButton.setTitle(
            reachability.isOnline ? SharedText.loadingLowercase : SharedText.offline,
            for: .disabled)
        activityIndicator.setAnimating(hideHints && isLoading && reachability.isOnline)
    }
    
    func enableDynamicType() {
        tableView.enableDynamicTypeReloading()
        downloadPostsTitleLabel.enableDynamicType(style: .callout)
        downloadPostsSaveButton.enableDynamicType(style: .callout, weight: .semibold)
        downloadPostsCancelButton.enableDynamicType(style: .callout)
        loadMoreButton.enableDynamicType(style: .subheadline)
        hintLabel.enableDynamicType(style: .body)
    }
    
    func updateStartDownloadsButtonEnabled() {
        downloadPostsSaveButton.isEnabled = futurePostsToDownload > 0
            || tableView.indexPathsForSelectedRows?.isEmpty == false
    }
    
    func updateChooseDownloadsButtonEnabled() {
        chooseDownloadsButton.isEnabled = !dataSource.rows.isEmpty && !isSavingOffline && reachability.isOnline
    }
    
    func updateSelectedRow() {
        undoPostProcessing = tableView.indexPathForSelectedRow.map(dataSource.processPostChanges(at:))
    }
    
    func reselectRowIfNeeded() {
        if navigationController?.topViewController is CommentsViewController,
            tableView.indexPathForSelectedRow == nil,
            let undo = undoPostProcessing {
            dataSource.undoProcessPostChanges(using: undo)
            undoPostProcessing = nil
        }
    }
    
    func updateSelectedRowsToDownload(updateSlider: Bool) {
        let numberOfSelectedPosts = (tableView.indexPathsForSelectedRows?.count ?? 0) + futurePostsToDownload
        if updateSlider {
            downloadPostsSlider.value = Float(numberOfSelectedPosts)
        }
        downloadPostsTitleLabel.text = String.localizedStringWithFormat(
            SharedText.savePostsFormat, numberOfSelectedPosts)
        updateStartDownloadsButtonEnabled()
    }
    
    func setDownloadPostsHeaderVisible(_ visible: Bool, animated: Bool) {
        // Stop unsatisfiable constraints by ensuring both aren't active at once
        downloadPostsHeaderHiding.isActive = false
        downloadPostsHeaderShowing.isActive = false
        (visible ? downloadPostsHeaderShowing : downloadPostsHeaderHiding)?.isActive = true
        
        guard animated else {
            navigationController?.setNavigationBarHidden(visible, animated: animated)
            return
        }
        
        let offsetAdjustment = visible ? max(0, downloadPostsHeader.frame.height - topLayoutGuide.length) : 0
        
        downloadPostsBackgroundView.isHidden = true
        (navigationController as? NavigationController)?.setNavigationBarHidden(
            visible,
            transitioningWith: downloadPostsHeader,
            additionalAnimations: {
                self.view.setNeedsLayout()
                self.view.layoutIfNeeded()
                if offsetAdjustment > 0 {
                    self.tableView.contentOffset.y -= offsetAdjustment
                }
        }, completion: {
            self.downloadPostsBackgroundView.isHidden = false
        })
    }
    
    func select(numberOfRows: Int, selectedIndexPaths: [IndexPath]) {
        for _ in 0..<numberOfRows {
            let selecting = (0..<dataSource.rows.count).first { row in
                !dataSource.rows[row].post.isAvailableOffline
                    && !selectedIndexPaths.contains { $0.row == row }
            }
            if let row = selecting {
                tableView.selectRow(at: IndexPath(row: row, section: 0), animated: true, scrollPosition: .none)
            } else {
                futurePostsToDownload += 1
            }
        }
    }
    
    func deselect(numberOfRows: Int, selectedIndexPaths: inout [IndexPath]) {
        for _ in 0..<numberOfRows {
            if futurePostsToDownload > 0 {
                futurePostsToDownload -= 1
            } else if !selectedIndexPaths.isEmpty {
                tableView.deselectRow(at: selectedIndexPaths.removeLast(), animated: true)
            }
        }
    }
    
    // MARK: - UI Actions
    
    @IBAction func chooseDownloadButtonPressed(_ sender: UIBarButtonItem) {
        setEditing(true, animated: true)
    }
    
    @IBAction func startDownloadsButtonPressed(_ sender: UIButton) {
        let indexPaths = tableView.indexPathsForSelectedRows ?? []
        if isEditing, indexPaths.count + futurePostsToDownload > 0 {
            startPostsDownload(for: indexPaths, additional: futurePostsToDownload)
        } else {
            setEditing(!isEditing, animated: true)
        }
    }
    
    @IBAction func cancelDownloadsButtonPressed(_ sender: UIButton) {
        setEditing(false, animated: true)
    }
    
    @IBAction func loadMoreButtonPressed(_ sender: UIButton) {
        if !isLoading && !isSavingOffline {
            dataSource.fetchNextPageOrReloadIfOffline()
        }
    }
    
    @IBAction func showSubredditsButtonPressed(_ sender: UIButton) {
        showSubredditsViewController()
    }
    
    @IBAction func filterButtonPressed(_ sender: UIBarButtonItem) {
        showFilterPostsViewController()
    }
    
    @IBAction func downloadPostsSliderValueChanged(_ sender: UISlider) {
        var selectedIndexPaths = tableView.indexPathsForSelectedRows?.sorted() ?? []
        let desiredNumberOfSelectedPosts = Int(sender.value.rounded())
        let numberOfSelectionsToChange = desiredNumberOfSelectedPosts - selectedIndexPaths.count - futurePostsToDownload
        if numberOfSelectionsToChange > 0 { // Selection
            select(numberOfRows: (0..<numberOfSelectionsToChange).count,
                   selectedIndexPaths: selectedIndexPaths)
        } else if numberOfSelectionsToChange < 0 { // Deselection
            deselect(numberOfRows: (numberOfSelectionsToChange..<0).count,
                     selectedIndexPaths: &selectedIndexPaths)
        }
        updateSelectedRowsToDownload(updateSlider: false)
    }
}
