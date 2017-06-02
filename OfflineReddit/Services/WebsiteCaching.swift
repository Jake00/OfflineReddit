//
//  WebsiteCaching.swift
//  OfflineReddit
//
//  Created by Jake Bellamy on 1/06/17.
//  Copyright © 2017 Jake Bellamy. All rights reserved.
//

import Foundation

class WebsiteCache: URLCache {
    
    let fileManager = FileManager.default
    var isEnabled = true
    
    static let directory = URL(fileURLWithPath:
        NSSearchPathForDirectoriesInDomains(.cachesDirectory, .userDomainMask, true)[0]
        ).appendingPathComponent("WebsiteCache")
    
    // MARK: - Init
    
    let reachability: Reachability
    
    init(reachability: Reachability) {
        self.reachability = reachability
        
        super.init(
            memoryCapacity: 500 * 1024 * 1024, // 500MB
            diskCapacity: 500 * 1024 * 1024, // 500MB
            diskPath: WebsiteCache.directory.path)
        
        createCacheDirectoryIfNeeded()
    }
    
    private func createCacheDirectoryIfNeeded() {
        guard !fileManager.fileExists(atPath: WebsiteCache.directory.path)
            else { return }
        do {
            try fileManager.createDirectory(at: WebsiteCache.directory, withIntermediateDirectories: true, attributes: nil)
        } catch {
            print("Failed creating the website cache directory at \(WebsiteCache.directory.path): \(error)")
        }
    }
    
    // MARK: - Caching
    
    override func cachedResponse(for request: URLRequest) -> CachedURLResponse? {
        guard isEnabled,
            // Validate request URL
            let requestURL = request.url, !requestURL.absoluteString.isEmpty,
            // Respect requests caching policy
            request.cachePolicy != .reloadIgnoringLocalAndRemoteCacheData,
            request.cachePolicy != .reloadIgnoringLocalCacheData,
            // Have we stored a response?
            let storageURL = self.storageURL(for: request),
            fileManager.fileExists(atPath: storageURL.path)
            else { return nil }
        
        return NSKeyedUnarchiver.unarchiveObject(withFile: storageURL.path) as? CachedURLResponse
    }
    
    override func storeCachedResponse(_ cachedResponse: CachedURLResponse, for request: URLRequest) {
        guard isEnabled,
            // Validate request URL
            let requestURL = request.url, !requestURL.absoluteString.isEmpty,
            // Respect requests caching policy
            request.cachePolicy != .reloadIgnoringLocalAndRemoteCacheData,
            request.cachePolicy != .reloadIgnoringLocalCacheData
            else { return }
        
        if let storageURL = self.storageURL(for: request) {
            if !NSKeyedArchiver.archiveRootObject(cachedResponse, toFile: storageURL.path) {
                print("Failed storing cached response for request to \(request.url?.absoluteString ?? "") stored at \(storageURL.path)")
            }
        }
    }
    
    override func removeCachedResponse(for request: URLRequest) {
        if let storageURL = self.storageURL(for: request) {
            do {
                try fileManager.removeItem(at: storageURL)
            } catch {
                print("Failed removing cached response for request to \(request.url?.absoluteString ?? "") stored at \(storageURL.path): \(error)")
            }
        }
    }
    
    func storageURL(for request: URLRequest) -> URL? {
        return request.url.map {
            WebsiteCache.directory.appendingPathComponent(String($0.hashValue))
        }
    }
}
