//
//  AuthorTime.swift
//  OfflineReddit
//
//  Created by Jake Bellamy on 20/03/17.
//  Copyright © 2017 Jake Bellamy. All rights reserved.
//

import Foundation

protocol AuthorTime {
    var author: String? { get }
    var created: Date? { get }
}

extension AuthorTime {
    
    var authorTimeText: String {
        let author = self.author.map { "u/" + $0 } ?? SharedText.unknown
        let time = created
            .flatMap { intervalFormatter.string(from: -$0.timeIntervalSinceNow) }
            .map { String.localizedStringWithFormat(SharedText.agoFormat, $0) }
            ?? SharedText.unknown
        return "\(author) • \(time)"
    }
}
