//
//  ImageDownloader.swift
//  OfflineReddit
//
//  Created by Jake Bellamy on 20/06/17.
//  Copyright © 2017 Jake Bellamy. All rights reserved.
//

import UIKit
import BoltsSwift

class ImageDownloader {
    
    typealias LoadCallback = (UIImage?) -> Void
    typealias ValidateCallback = (Error?) -> Void
    
    static let shared = ImageDownloader()
    let session: URLSession
    
    var isMemoryCachingEnabled = true {
        didSet {
            if !isMemoryCachingEnabled {
                cache.removeAllObjects()
            }
        }
    }
    
    private let queue = DispatchQueue(label: "jrb.OfflineReddit.ImageDownloader.queue")
    private var requests: [String: Request] = [:]
    private let maximumActiveDownloads = 4
    private var currentActiveDownloads = 0
    private var queuedRequests: [Request] = []
    private var cache = NSCache<NSString, UIImage>()
    
    struct Request: Hashable {
        let url: URL
        let task: URLSessionDataTask
        var completors: [LoadCallback]
        var validators: [ValidateCallback]
        
        static func == (lhs: Request, rhs: Request) -> Bool {
            return lhs.url.absoluteString == rhs.url.absoluteString
        }
        var hashValue: Int { return url.absoluteString.hashValue }
    }
    
    init() {
        let configuration = URLSessionConfiguration.default
        configuration.urlCache = URLCache(
            memoryCapacity: 0,
            diskCapacity: 500 * 1024 * 1024,  // 500 MB
            diskPath: "jrb.OfflineReddit.ImageDownloader"
        )
        self.session = URLSession(configuration: configuration)
    }
    
    func load(url: URL, completion: @escaping LoadCallback) {
        /* 1. Check in memory cache for an existing image. */
        if isMemoryCachingEnabled, let cachedImage = cache.object(forKey: url.absoluteString as NSString) {
            completion(cachedImage)
            return
        }
        
        /* 2. Check for an existing request, append the completion handler if it exists. */
        let existingRequest = queue.sync { () -> Request? in
            if var request = requests[url.absoluteString], !request.completors.isEmpty {
                request.completors.append(completion)
                requests[url.absoluteString] = request
                return request
            }
            return nil
        }
        if let _ = existingRequest {
            return
        }
        
        /* 3. Create new task to download the image. */
        let task = session.dataTask(with: url) { data, _, error in
            let image = data.flatMap(UIImage.init)?.inflated
            image?.loadedFromURL = url
            if let image = image, self.isMemoryCachingEnabled {
                self.cache.setObject(
                    image,
                    forKey: url.absoluteString as NSString,
                    cost: Int(image.size.width * image.size.height))
            }
            self.queue.sync {
                let request = self.remove(url: url)
                self.startNextRequestIfNeeded()
                DispatchQueue.main.async {
                    request?.completors.forEach { $0(image) }
                    request?.validators.forEach { $0(error) }
                }
            }
        }
        let request = Request(url: url, task: task, completors: [completion], validators: [])
        queue.sync {
            requests[url.absoluteString] = request
            
            /* 4. Either start the request or enqueue it depending on other concurrent downloads. */
            if currentActiveDownloads < maximumActiveDownloads {
                start(request)
            } else {
                queuedRequests.append(request)
            }
        }
    }
    
    func load(url: URL) -> Task<UIImage?> {
        let completion = TaskCompletionSource<UIImage?>()
        load(url: url, completion: completion.set)
        return completion.task
    }
    
    func cancelRequest(url: URL) {
        queue.sync {
            remove(url: url)?.task.cancel()
            startNextRequestIfNeeded()
        }
    }
    
    func validate(url: URL, completion: @escaping ValidateCallback) {
        /* 1. Check in memory cache for an existing image. Assume URL is valid if one is found. */
        if isMemoryCachingEnabled, cache.object(forKey: url.absoluteString as NSString) != nil {
            completion(nil)
            return
        }
        
        /* 2. Check for an existing request, append the completion handler if it exists. */
        let existingRequest = queue.sync { () -> Request? in
            if var request = requests[url.absoluteString] {
                request.validators.append(completion)
                requests[url.absoluteString] = request
                return request
            }
            return nil
        }
        if let _ = existingRequest {
            return
        }
        
        /* 3. Create new task to request the metadata about the image. */
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = APIClient.Method.head.rawValue
        let task = session.dataTask(with: urlRequest) { data, response, error in
            let error = error ?? response.validateIsImage()
            let image = data.flatMap(UIImage.init)?.inflated
            if let image = image, self.isMemoryCachingEnabled {
                self.cache.setObject(
                    image,
                    forKey: url.absoluteString as NSString,
                    cost: Int(image.size.width * image.size.height))
            }
            self.queue.sync {
                let request = self.remove(url: url)
                self.startNextRequestIfNeeded()
                DispatchQueue.main.async {
                    request?.validators.forEach { $0(error) }
                    if let image = image {
                        request?.completors.forEach { $0(image) }
                    }
                }
            }
        }
        let request = Request(url: url, task: task, completors: [], validators: [completion])
        queue.sync {
            requests[url.absoluteString] = request
            
            /* 4. Either start the request or enqueue it depending on other concurrent downloads. */
            if currentActiveDownloads < maximumActiveDownloads {
                start(request)
            } else {
                queuedRequests.append(request)
            }
        }
    }
    
    func validate(url: URL) -> Task<Void> {
        let completion = TaskCompletionSource<Void>()
        validate(url: url) { error in
            if let error = error {
                completion.set(error: error)
            } else {
                completion.set(result: ())
            }
        }
        return completion.task
    }
    
    private func remove(url: URL) -> Request? {
        if currentActiveDownloads > 0 {
            currentActiveDownloads -= 1
        }
        return requests.removeValue(forKey: url.absoluteString)
    }
    
    private func startNextRequestIfNeeded() {
        guard currentActiveDownloads < maximumActiveDownloads else { return }
        
        while !queuedRequests.isEmpty {
            let request = queuedRequests.removeFirst()
            if request.task.state == .suspended {
                start(request)
            }
        }
    }
    
    private func start(_ request: Request) {
        request.task.resume()
        currentActiveDownloads += 1
    }
}

private extension UIImage {
    
    var inflated: UIImage {
        guard let cgImage = cgImage else { return self }
        
        let frame       = CGRect(x: 0, y: 0, width: cgImage.width, height: cgImage.height)
        let colorSpace  = CGColorSpaceCreateDeviceRGB()
        var bitmapInfo  = cgImage.bitmapInfo
        let infoMask    = bitmapInfo.intersection(.alphaInfoMask).rawValue
        let anyNonAlpha = infoMask == CGImageAlphaInfo.none.rawValue
            ||            infoMask == CGImageAlphaInfo.noneSkipFirst.rawValue
            ||            infoMask == CGImageAlphaInfo.noneSkipLast.rawValue
        
        // CGBitmapContextCreate doesn't support kCGImageAlphaNone with RGB.
        // https://developer.apple.com/library/mac/#qa/qa1037/_index.html
        if infoMask == CGImageAlphaInfo.none.rawValue && colorSpace.numberOfComponents > 1 {
            bitmapInfo.remove(.alphaInfoMask)
            bitmapInfo.insert(CGBitmapInfo(rawValue: CGImageAlphaInfo.noneSkipFirst.rawValue))
        } else if !anyNonAlpha && colorSpace.numberOfComponents == 3 {
            bitmapInfo.remove(.alphaInfoMask)
            bitmapInfo.insert(CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedFirst.rawValue))
        }
        
        guard let context = CGContext(
            data:             nil,
            width:            cgImage.width,
            height:           cgImage.height,
            bitsPerComponent: cgImage.bitsPerComponent,
            bytesPerRow:      0,
            space:            colorSpace,
            bitmapInfo:       bitmapInfo.rawValue)
            else { return self }
        
        context.draw(cgImage, in: frame)
        guard let decompressed = context.makeImage() else { return self }
        return UIImage(cgImage: decompressed, scale: scale, orientation: imageOrientation)
    }
    
    var loadedFromURL: URL? {
        get { return objc_getAssociatedObject(self, &loadedFromURLKey) as? URL }
        set { objc_setAssociatedObject(self, &loadedFromURLKey, newValue, .OBJC_ASSOCIATION_COPY_NONATOMIC) }
    }
}

private var loadedFromURLKey = 666
private var activeImageLoadURLKey = 777
private var activityIndicatorViewKey = 888

extension UIImageView {
    
    var activeImageLoadURL: URL? {
        get { return objc_getAssociatedObject(self, &activeImageLoadURLKey) as? URL }
        set { objc_setAssociatedObject(self, &activeImageLoadURLKey, newValue, .OBJC_ASSOCIATION_COPY_NONATOMIC) }
    }
    
    struct SetImageOptions: OptionSet {
        let rawValue: Int
        static let fade = SetImageOptions(rawValue: 1 << 0)
        static let load = SetImageOptions(rawValue: 1 << 1)
    }
    
    typealias SetImageCallback = (UIImageView, UIImage?) -> Void
    
    func setImage(url: URL?, options: SetImageOptions = [.fade, .load], completion: SetImageCallback? = nil) {
        if url == image?.loadedFromURL {
            return
        }
        if let activeImageLoadURL = activeImageLoadURL {
            if url?.absoluteString == activeImageLoadURL.absoluteString {
                return
            } else {
                ImageDownloader.shared.cancelRequest(url: activeImageLoadURL)
            }
        }
        image = nil
        activeImageLoadURL = url
        guard let url = url else { return }
        if options.contains(.load) {
            showLoader()
        }
        ImageDownloader.shared.load(url: url) { [weak self] image in
            guard let s = self else { return }
            if options.contains(.fade) {
                s.alpha = 0
                s.image = image
                UIView.animate(withDuration: 0.2) { s.alpha = 1 }
            } else {
                s.image = image
            }
            s.activeImageLoadURL = nil
            s.activityIndicatorView?.stopAnimating()
            completion?(s, image)
        }
    }
    
    private var activityIndicatorView: UIActivityIndicatorView? {
        get { return objc_getAssociatedObject(self, &activityIndicatorViewKey) as? UIActivityIndicatorView }
        set { objc_setAssociatedObject(self, &activityIndicatorViewKey, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC) }
    }
    
    private func showLoader() {
        let activityIndicatorView = self.activityIndicatorView ?? {
            let activityIndicatorView = UIActivityIndicatorView(activityIndicatorStyle: .gray)
            activityIndicatorView.translatesAutoresizingMaskIntoConstraints = false
            self.activityIndicatorView = activityIndicatorView
            addSubview(activityIndicatorView)
            NSLayoutConstraint.activate([
                centerYAnchor.constraint(equalTo: activityIndicatorView.centerYAnchor),
                centerXAnchor.constraint(equalTo: activityIndicatorView.centerXAnchor)
                ])
            return activityIndicatorView
        }()
        activityIndicatorView.startAnimating()
    }
}
