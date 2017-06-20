//
//  PostImagePreviews.swift
//  OfflineReddit
//
//  Created by Jake Bellamy on 20/06/17.
//  Copyright © 2017 Jake Bellamy. All rights reserved.
//

import UIKit

struct PostImagePreviews {
    
    struct Image {
        let stills: [ImageURL]
        let gifs: [ImageURL]
        let mp4s: [ImageURL]
        let obfuscated: [ImageURL]
    }
    
    let images: [Image]
    
    init?(json: JSON?) {
        guard let images = json?["images"] as? [JSON] else { return nil }
        self.images = images.flatMap { json in
            guard let stills = mapImageURLs(json: json) else { return nil }
            let variants = json["variants"] as? JSON
            let gifs = mapImageURLs(json: variants?["gif"] as? JSON)
            let mp4s = mapImageURLs(json: variants?["mp4"] as? JSON)
            let obfuscated = mapImageURLs(json: variants?["obfuscated"] as? JSON)
            return Image(
                stills: stills.sorted(),
                gifs: gifs?.sorted() ?? [],
                mp4s: mp4s?.sorted() ?? [],
                obfuscated: obfuscated?.sorted() ?? [])
        }
        if self.images.isEmpty {
            return nil
        }
    }
    
    func imageURL(fitting size: CGSize) -> ImageURL? {
        return images.first?.stills.first {
            $0.size.width >= size.width && $0.size.height >= size.height
        } ?? images.first?.stills.last
    }
}

private func mapImageURLs(json: JSON?) -> [ImageURL]? {
    let sourceJSON = json?["source"] as? JSON
    guard let source = sourceJSON.flatMap(ImageURL.init(json:)) else { return nil }
    let resolutionsJSON = json?["resolutions"] as? [JSON]
    let resolutions = resolutionsJSON?.flatMap(ImageURL.init(json:))
    return resolutions.map { [source] + $0 } ?? [source]
}
