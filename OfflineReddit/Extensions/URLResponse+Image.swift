//
//  URLResponse+Image.swift
//  OfflineReddit
//
//  Created by Jake Bellamy on 20/06/17.
//  Copyright © 2017 Jake Bellamy. All rights reserved.
//
// swiftlint:disable line_length

import Foundation

extension URLResponse {
    
    enum ImageValidationError: Error, PresentableError {
        case emptyResponse
        case notAnImage
        
        var alertTitle: String? {
            switch self {
            case .emptyResponse: return nil
            case .notAnImage: return NSLocalizedString("image_validation.error_title.not_an_image", value: "Not an image URL", comment: "The title of an error alert when the provided URL did not resolve to an image.")
            }
        }
        
        var alertMessage: String? {
            switch self {
            case .emptyResponse: return NSLocalizedString("image_validation.error_message.empty_response", value: "No response was received from that URL. Try again or use a different URL.", comment: "The message of an error alert when the an empty response was received via image validation.")
            case .notAnImage: return NSLocalizedString("image_validation.error_message.not_an_image", value: "Make sure you entered the direct image URL. In your browser, long or force press on an image, not a link, and select copy.", comment: "The message of an error alert when the provided URL did not resolve to an image.")
            }
        }
    }
    
    func validateIsImage() -> Error? {
        guard let mimeType = mimeType
            else { return ImageValidationError.emptyResponse }
        guard let range = mimeType.range(of: "image", options: .caseInsensitive),
            range.lowerBound == mimeType.startIndex
            else { return ImageValidationError.notAnImage }
        return nil
    }
}

extension Optional where Wrapped == URLResponse {
    
    func validateIsImage() -> Error? {
        if let s = self {
            return s.validateIsImage()
        }
        return URLResponse.ImageValidationError.emptyResponse
    }
}
