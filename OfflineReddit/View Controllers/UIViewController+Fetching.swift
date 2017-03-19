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

extension UIViewController {
    
    func presentErrorAlert(error: Error) {
        let presentableError = error as? PresentableError
        let title = presentableError?.alertTitle ?? NSLocalizedString("error_alert.title", value: "Sorry, something went wrong", comment: "The title of an error alert.")
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
}

protocol PresentableError {
    var alertTitle: String? { get }
    var alertMessage: String? { get }
}
