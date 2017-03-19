//
//  APIClient+URLSessionDelegate.swift
//  ThisOrThat
//
//  Created by Jake Bellamy on 11/12/16.
//  Copyright © 2016 Jake Bellamy. All rights reserved.
//

import Foundation

extension APIClient: URLSessionDelegate {
    
    func urlSession(_ session: URLSession, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        if challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust,
            challenge.protectionSpace.host == base.url.host,
            let trust = challenge.protectionSpace.serverTrust {
            completionHandler(.useCredential, URLCredential(trust: trust))
        }
    }
}
