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
    @IBOutlet var footerView: UIView!
    @IBOutlet var inputToolbar: UIToolbar!
    
    let context = CoreDataController.shared.viewContext
    var didSelectSubreddits: (([Subreddit]) -> Void)?
    var subreddits: [Subreddit] = []
    
    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.tableFooterView = footerView
        tableView.register(UINib(nibName: String(describing: SubredditCell.self), bundle: nil), forCellReuseIdentifier: String(describing: SubredditCell.self))
        newTextField.inputAccessoryView = inputToolbar
        navigationItem.rightBarButtonItem = editButtonItem
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillAppear(_:)), name: .UIKeyboardWillShow, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillDisappear(_:)), name: .UIKeyboardWillHide, object: nil)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        if subreddits.isEmpty {
            let request: NSFetchRequest<Subreddit> = Subreddit.fetchRequest()
            request.sortDescriptors = [NSSortDescriptor(key: "name", ascending: true)]
            subreddits = (try? context.fetch(request)) ?? []
            if subreddits.isEmpty {
                subreddits = Subreddit.insertDefaults(into: context)
            }
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        didSelectSubreddits?(subreddits.filter { $0.isSelected })
        if context.hasChanges {
            _ = try? context.save()
        }
    }
    
    override func setEditing(_ editing: Bool, animated: Bool) {
        super.setEditing(editing, animated: animated)
        tableView.setEditing(editing, animated: animated)
    }
    
    func keyboardWillAppear(_ notification: Notification) {
        if let height = (notification.userInfo?[UIKeyboardFrameEndUserInfoKey] as? CGRect)?.height {
            tableView.contentInset.bottom = height
            tableView.scrollIndicatorInsets.bottom = height
        }
    }
    
    func keyboardWillDisappear(_ notification: Notification) {
        tableView.contentInset.bottom = 0
        tableView.scrollIndicatorInsets.bottom = 0
    }
    
    @IBAction func doneButtonPressed(_ sender: UIBarButtonItem) {
        newTextField.resignFirstResponder()
    }
}

// MARK: - Table view data source

extension SubredditsViewController: UITableViewDataSource {
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return subreddits.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "SubredditCell", for: indexPath) as! SubredditCell
        let subreddit = subreddits[indexPath.row]
        cell.textLabel?.text = subreddit.name
        cell.isChecked = subreddit.isSelected
        return cell
    }
    
    func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCellEditingStyle, forRowAt indexPath: IndexPath) {
        guard editingStyle == .delete else { return }
        context.delete(subreddits.remove(at: indexPath.row))
        tableView.deleteRows(at: [indexPath], with: .automatic)
    }
}

// MARK: - Table view delegate

extension SubredditsViewController: UITableViewDelegate {
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let subreddit = subreddits[indexPath.row]
        subreddit.isSelected = !subreddit.isSelected
        (tableView.cellForRow(at: indexPath) as? SubredditCell)?.isChecked = subreddit.isSelected
    }
}

// MARK: - Text field delegate

extension SubredditsViewController: UITextFieldDelegate {
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        guard let name = textField.text, !name.isEmpty else { return false }
        
        let indexPath = IndexPath(row: subreddits.endIndex, section: 0)
        let subreddit = Subreddit.create(in: context, name: name)
        subreddits.append(subreddit)
        tableView.insertRows(at: [indexPath], with: .automatic)
        tableView.selectRow(at: indexPath, animated: false, scrollPosition: .bottom)
        textField.text = nil
        return textField.resignFirstResponder()
    }
}

// MARK: - Storyboard init

extension SubredditsViewController: StoryboardInitializable {
    static let storyboardIdentifier = "Subreddits"
}
