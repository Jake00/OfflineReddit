//
//  SubredditsViewController.swift
//  OfflineReddit
//
//  Created by Jake Bellamy on 21/03/17.
//  Copyright © 2017 Jake Bellamy. All rights reserved.
//

import UIKit
import CoreData

class SubredditsViewController: UIViewController {
    
    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var newTextField: UITextField!
    @IBOutlet weak var saveSubredditButton: UIBarButtonItem!
    @IBOutlet var footerView: UIView!
    @IBOutlet var inputToolbar: UIToolbar!
    
    var didSelectSubreddits: (([Subreddit]) -> Void)?
    let dataSource: SubredditsDataSource
    
    // MARK: - Init
    
    init(provider: DataProvider) {
        dataSource = SubredditsDataSource(provider: provider)
        super.init(nibName: String(describing: SubredditsViewController.self), bundle: nil)
    }
    
    @available(*, unavailable, message: "init(coder:) is not available. Use init(provider:) instead.")
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) is not available. Use init(provider:) instead.")
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    // MARK: - View controller
    
    override func viewDidLoad() {
        super.viewDidLoad()
        dataSource.tableView = tableView
        tableView.dataSource = dataSource
        tableView.delegate = dataSource
        tableView.tableFooterView = footerView
        tableView.registerReusableNibCell(SubredditCell.self)
        newTextField.inputAccessoryView = inputToolbar
        navigationItem.rightBarButtonItem = editButtonItem
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillAppear(_:)), name: .UIKeyboardWillShow, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillDisappear(_:)), name: .UIKeyboardWillHide, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(textFieldTextChanged(_:)), name: .UITextFieldTextDidChange, object: newTextField)
        
        dataSource.fillSubreddits()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        if dataSource.provider.local.hasChanges {
            didSelectSubreddits?(dataSource.subreddits.filter { $0.isSelected })
            _ = try? dataSource.provider.local.save()
        }
    }
    
    override func setEditing(_ editing: Bool, animated: Bool) {
        super.setEditing(editing, animated: animated)
        tableView.setEditing(editing, animated: animated)
    }
    
    // MARK: - Notifications
    
    func keyboardWillAppear(_ notification: Notification) {
        guard let height = (notification.userInfo?[UIKeyboardFrameEndUserInfoKey] as? CGRect)?.height else { return }
        tableView.contentInset.bottom = height
        tableView.scrollIndicatorInsets.bottom = height
        let duration = notification.userInfo?[UIKeyboardAnimationDurationUserInfoKey] as? TimeInterval ?? 0
        let rawCurve = notification.userInfo?[UIKeyboardAnimationCurveUserInfoKey] as? Int ?? 0
        UIView.animate(withDuration: duration, delay: 0, options: UIViewAnimationOptions(rawValue: UInt(rawCurve << 16)), animations: { 
            self.tableView.contentOffset.y = self.tableView.contentSize.height - self.tableView.frame.height + height
        }, completion: nil)
    }
    
    func keyboardWillDisappear(_ notification: Notification) {
        tableView.contentInset.bottom = 0
        tableView.scrollIndicatorInsets.bottom = 0
    }
    
    func textFieldTextChanged(_ notification: Notification) {
        saveSubredditButton.isEnabled = newTextField.hasText
    }
    
    // MARK: - UI Actions
    
    @IBAction func doneButtonPressed(_ sender: UIBarButtonItem) {
        newTextField.resignFirstResponder()
    }
    
    @IBAction func saveButtonPressed(_ sender: UIBarButtonItem) {
        attemptSubredditInsert(named: newTextField.text)
        sender.isEnabled = false
    }
    
    @discardableResult
    func attemptSubredditInsert(named subredditName: String?) -> Bool {
        guard let subredditName = subredditName, !subredditName.isEmpty
            else { return false }
        dataSource.insertSubreddit(named: subredditName)
        newTextField.text = nil
        return true
    }
}

extension SubredditsViewController: UITextFieldDelegate {
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        return attemptSubredditInsert(named: textField.text)
            && textField.resignFirstResponder()
    }
}
