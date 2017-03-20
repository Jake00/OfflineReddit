//
//  APIClient.swift
//  ThisOrThat
//
//  Created by Jake Bellamy on 25/11/16.
//  Copyright © 2016 Jake Bellamy. All rights reserved.
//

import Foundation

final class APIClient: NSObject {
    
    static let shared = APIClient()
    
    static var loggingLevel: LoggingLevel = isDebugBuild ? .verbose : .off
    
    var base: Base = .production
    
    var mapper = Mapper()
    
    let queue: OperationQueue = {
        let queue = OperationQueue()
        queue.maxConcurrentOperationCount = 3
        return queue
    }()
    
    lazy var session: URLSession = {
        let configuration = URLSessionConfiguration.default
        configuration.httpAdditionalHeaders = [
            "Content-Type": "application/json; charset=utf-8",
            "accept": "application/json",
            "User-Agent": "ios:jrb.RedditOffline:v0.1 (by u/jefftex)"
        ]
        return URLSession(configuration: configuration, delegate: self, delegateQueue: nil)
    }()
    
    enum Base: String {
        case production = "https://www.reddit.com"
        
        var url: URL {
            // swiftlint:disable:next force_unwrapping
            return URL(string: rawValue)!
        }
    }
    
    enum Method: String {
        case options = "OPTIONS"
        case get     = "GET"
        case head    = "HEAD"
        case post    = "POST"
        case put     = "PUT"
        case patch   = "PATCH"
        case delete  = "DELETE"
        case trace   = "TRACE"
        case connect = "CONNECT"
        
        var encodesParametersInURL: Bool {
            switch self {
            case .get, .head, .delete: return true
            default:                   return false
            }
        }
        
        var nilParameters: Parameters? {
            switch self { // POST, PUT and PATCH require an empty object if there is nothing to send.
            case .post, .put, .patch: return [:]
            default:                  return nil
            }
        }
    }
    
    enum Errors: Error {
        case emptyResponse
        case invalidResponse
        case missingFields
    }
    
    struct Request {
        let method: Method
        let path: String
        let parameters: Parameters?
        
        init(_ method: Method, _ path: String, parameters: Parameters? = nil) {
            self.method = method; self.path = path; self.parameters = parameters
        }
    }
    
    typealias Parameters = [String: Any]
    typealias CompletionHandler = (Data?, URLResponse?, Error?) -> Void
    
    @discardableResult
    func sendRequest(_ request: Request, completionHandler: @escaping CompletionHandler) -> URLSessionDataTask {
        guard let url = URL(string: request.path, relativeTo: base.url) else {
            fatalError("Invalid URL provided to \(self): \(request.path)")
        }
        
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = request.method.rawValue
        encode(&urlRequest, with: request.parameters, url, request.method)
        
        let operation = NetworkOperation()
        let task = session.dataTask(with: urlRequest) { data, response, error in
            APIClient.logResponse(data, response, error, url)
            operation.complete()
            completionHandler(data, response, error)
        }
        operation.task = task
        queue.addOperation(operation)
        
        return task
    }
    
    func encode(_ request: inout URLRequest, with parameters: Parameters?, _ url: URL, _ method: Method) {
        if method.encodesParametersInURL {
            if var components = URLComponents(url: url, resolvingAgainstBaseURL: true), parameters?.isEmpty == false {
                guard let parameters = parameters as? [String: String] else {
                    fatalError("Only string types are supported in query parameters. No arrays, dictionaries or other types.")
                }
                components.queryItems = parameters.map(URLQueryItem.init)
                request.url = components.url
            }
        } else {
            if let parameters = parameters ?? method.nilParameters {
                request.httpBody = try? JSONSerialization.data(withJSONObject: parameters, options: [])
            }
        }
    }
}
