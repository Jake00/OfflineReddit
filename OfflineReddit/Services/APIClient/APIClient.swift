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
    
    static var loggingLevel: LoggingLevel = isDebugBuild ? .simple : .off
    
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
    
    enum Errors: Error, PresentableError {
        case emptyResponse
        case invalidResponse
        case missingFields
        
        var alertTitle: String? { return nil }
        var alertMessage: String? {
            switch self {
            case .emptyResponse: return NSLocalizedString("api_error.empty_response", value: "There was no data returned.", comment: "Unexpected empty response error message.")
            case .invalidResponse: return NSLocalizedString("api_error.invalid_response", value: "Received an invalid response.", comment: "Invalid response error message.")
            case .missingFields: return NSLocalizedString("api_error.missing_fields", value: "We are missing data for making this request.", comment: "Unexpected empty response error message.")
            }
        }
    }
    
    struct Request {
        let method: Method
        let path: String
        let parameters: Parameters?
        let encoding: BodyEncoding
        
        init(_ method: Method, _ path: String, parameters: Parameters? = nil, encoding: BodyEncoding = .formData) {
            self.method = method; self.path = path; self.parameters = parameters; self.encoding = encoding
        }
        
        enum BodyEncoding {
            case json, formData
        }
    }
    
    typealias Parameters = [String: Any]
    typealias CompletionHandler = (Data?, URLResponse?, Error?) -> Void
    
    @discardableResult
    func sendRequest(_ request: Request, completionHandler: @escaping CompletionHandler) -> URLSessionDataTask {
        guard let url = URL(string: request.path, relativeTo: base.url)
            ?? request.path.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed).flatMap({ URL(string: $0, relativeTo: base.url) }) else {
                fatalError("Invalid URL provided to \(self): \(request.path)")
        }
        
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = request.method.rawValue
        encode(&urlRequest, with: request, url)
        
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
    
    func encode(_ urlRequest: inout URLRequest, with request: Request, _ url: URL) {
        if request.method.encodesParametersInURL {
            if var components = URLComponents(url: url, resolvingAgainstBaseURL: true), request.parameters?.isEmpty == false {
                guard let parameters = request.parameters as? [String: String] else {
                    fatalError("Only string types are supported in query parameters. No arrays, dictionaries or other types.")
                }
                components.queryItems = parameters.map(URLQueryItem.init)
                urlRequest.url = components.url
            }
            return
        }
        switch request.encoding {
        case .json:
            if let parameters = request.parameters ?? request.method.nilParameters {
                urlRequest.setValue("application/json; charset=utf-8", forHTTPHeaderField: "Content-Type")
                urlRequest.httpBody = try? JSONSerialization.data(withJSONObject: parameters, options: [])
            }
        case .formData:
            guard request.parameters?.isEmpty == false else { return }
            let boundary = "----" + UUID().uuidString
            guard let boundaryData = "--\(boundary)\r\n".data(using: .utf8) else { return }
            urlRequest.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
            
            var body = Data()
            for (key, value) in request.parameters ?? [:] {
                if let data = "Content-Disposition: form-data; name=\"\(key)\"\r\n\r\n\(value)\r\n".data(using: .utf8) {
                    body.append(boundaryData)
                    body.append(data)
                }
            }
            urlRequest.httpBody = body
        }
    }
}
