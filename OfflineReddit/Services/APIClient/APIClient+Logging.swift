//
//  APIClient+Logging.swift
//  ThisOrThat
//
//  Created by Jake Bellamy on 25/11/16.
//  Copyright © 2016 Jake Bellamy. All rights reserved.
//

import Foundation

extension APIClient {
    
    enum LoggingLevel {
        case off, simple, verbose
    }
    
    private static func prettyPrintedJSON(from data: Data) -> String? {
        return (try? JSONSerialization.jsonObject(with: data, options: []))
            .flatMap { try? JSONSerialization.data(withJSONObject: $0, options: .prettyPrinted) }
            .flatMap { String(data: $0, encoding: .utf8) }
    }
    
    private static func printableBody(from data: Data?) -> String? {
        return data.flatMap { prettyPrintedJSON(from: $0) ?? String(data: $0, encoding: .utf8) }
    }
    
    static func logRequest(_ task: URLSessionTask) {
        guard loggingLevel != .off else { return }
        
        guard let request = task.originalRequest,
            let method = request.httpMethod,
            let path = request.url?.absoluteString
            else { return }
        
        var logged = "\(method) \(path)"
        
        if loggingLevel == .verbose {
            if let headers = request.allHTTPHeaderFields, !headers.isEmpty {
                logged += ", headers: \(headers.description)"
            }
            if let body = printableBody(from: request.httpBody) {
                logged += ", body: \(body)"
            }
        }
        print(logged)
    }
    
    static func logResponse(_ data: Data?, _ response: URLResponse?, _ error: Swift.Error?, _ url: URL) {
        guard loggingLevel != .off else { return }
        
        guard let response = response else {
            if let error = error {
                print("XXX \(url.absoluteString): \"\((error as? LocalizedError)?.errorDescription ?? (error as NSError).localizedDescription)\"")
            }
            return
        }
        
        guard let path = response.url?.absoluteString else { return }
        
        let statusCode = (response as? HTTPURLResponse).map { String($0.statusCode) } ?? "N/A"
        
        if let body = printableBody(from: data), loggingLevel == .verbose {
            print("\(statusCode) \(path): \"\(body)\"")
        } else {
            print("\(statusCode) \(path)")
        }
    }
}
