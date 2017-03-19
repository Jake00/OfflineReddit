//
//  APIClient+Response.swift
//  ThisOrThat
//
//  Created by Jake Bellamy on 4/12/16.
//  Copyright © 2016 Jake Bellamy. All rights reserved.
//

import Foundation
import CoreData
import BoltsSwift

extension APIClient {
    
    func sendTaskRequest(_ request: Request) -> Task<(Data, HTTPURLResponse)> {
        let completion = TaskCompletionSource<(Data, HTTPURLResponse)>()
        sendRequest(request) { data, response, error in
            let response = response as? HTTPURLResponse
            if let error = error {
                completion.set(error: error)
            } else if let data = data, let response = response {
                completion.set(result: (data, response))
            } else {
                completion.set(error: Errors.emptyResponse)
            }
        }
        return completion.task
    }
    
    func sendJSONRequest(_ request: Request, options: JSONSerialization.ReadingOptions = []) -> Task<Any> {
        return sendTaskRequest(request).continueOnSuccessWith(.immediate) {
            try JSONSerialization.jsonObject(with: $0.0, options: options)
        }
    }
    
    func sendVoidRequest(_ request: Request) -> Task<Void> {
        return sendTaskRequest(request).continueWith(.immediate) { task -> Void in
            guard let error = task.error else { return }
            if case Errors.emptyResponse = error {
                return
            }
            throw error
        }
    }
}
