//
//  ImageURL.swift
//  OfflineReddit
//
//  Created by Jake Bellamy on 20/06/17.
//  Copyright © 2017 Jake Bellamy. All rights reserved.
//

import UIKit

struct ImageURL {
    
    let size: CGSize
    let url: URL
    
    var area: CGFloat {
        return size.width * size.height
    }
    
    var aspectRatio: CGFloat {
        return size.width / size.height
    }
    
    init(size: CGSize, url: URL) {
        self.size = size
        self.url = url
    }
    
    init?(json: JSON) {
        guard let urlString = json["url"] as? String,
            let url = URL(string: urlString),
            let width = json["width"] as? Double,
            let height = json["height"] as? Double
            else { return nil }
        self.size = CGSize(width: width, height: height)
        self.url = url
    }
}

// MARK: - Equatable

extension ImageURL: Equatable {
    
    static func == (lhs: ImageURL, rhs: ImageURL) -> Bool {
        return lhs.size == rhs.size && lhs.url == rhs.url
    }
}

// MARK: - Hashable

extension ImageURL: Hashable {
    
    var hashValue: Int {
        return area.hashValue &+ url.hashValue
    }
}

// MARK: - Comparable

extension ImageURL: Comparable {
    
    static func < (lhs: ImageURL, rhs: ImageURL) -> Bool {
        return lhs.area < rhs.area
    }
}
