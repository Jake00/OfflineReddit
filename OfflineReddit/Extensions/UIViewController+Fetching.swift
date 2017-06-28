//
//  UIViewController+Fetching.swift
//  ThisOrThat
//
//  Created by Jake Bellamy on 9/12/16.
//  Copyright © 2016 Jake Bellamy. All rights reserved.
//

import Foundation
import UIKit
import BoltsSwift

protocol Loadable: class {
    var isLoading: Bool { get set }
}

extension UIViewController {
    
    var navigationBarProgressView: UIProgressView? {
        return (navigationController as? NavigationController)?.progressView
    }
    
    func presentErrorAlert(error: Error) {
        let presentableError = error as? PresentableError
        let title = presentableError?.alertTitle
            ?? NSLocalizedString("error_alert.title", value: "Sorry, something went wrong", comment: "The title of an error alert.") // swiftlint:disable:this line_length
        let message: String?
        if let presentableError = presentableError {
            message = presentableError.alertMessage
        } else {
            message = (error as? LocalizedError)?.errorDescription ?? (error as NSError).localizedDescription
        }
        presentOkAlert(title: title, message: message)
    }
    
    func presentOkAlert(title: String, message: String? = nil) {
        let okTitle = NSLocalizedString("error_alert.action_ok", value: "OK", comment: "The 'OK' action for an alert.")
        let alertController = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alertController.addAction(UIAlertAction(title: okTitle, style: .default, handler: nil))
        present(alertController, animated: true, completion: nil)
    }
    
    @discardableResult
    func fetch<T>(_ task: Task<T>) -> Task<T> {
        (self as? Loadable)?.isLoading = true
        return task.continueWithTask(.mainThread) { task in
            (self as? Loadable)?.isLoading = false
            task.error.map(self.presentErrorAlert)
            return task
        }
    }
}

protocol PresentableError {
    var alertTitle: String? { get }
    var alertMessage: String? { get }
}
