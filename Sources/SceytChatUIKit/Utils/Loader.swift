//
//  Loader.swift
//  SceytChatUIKit
//
//  Created by Hovsep Keropyan on 26.10.23.
//  Copyright © 2023 Sceyt LLC. All rights reserved.
//

import UIKit

public protocol Cancellable {
    func cancel()
}

open class Session: NSObject {

    @discardableResult
    public class func download(url: URL,
                                progressHandler: ((Progress) -> Void)? = nil,
                                completion: ((_ result: Result<URL, Error>) -> Void)? = nil)
    -> Cancellable? {

        let request = URLRequest(url: url)

        return URLSession.shared.downloadTask(with: request) { responseUrl, response, error in
            if let error = error ?? Self.statusError(response) {
                completion?(.failure(error))
            } else if let responseUrl = responseUrl {
                completion?(.success(responseUrl))
            }
        }.start().handleProgress { progress in
            progressHandler?(progress)
        }
    }

    /// A download task hands back the response body whatever the status, so a 404 arrives as a
    /// "downloaded" error page. Stored as the file, it read as finished and was never fetched
    /// again.
    static func statusError(_ response: URLResponse?) -> Error? {
        guard let statusCode = (response as? HTTPURLResponse)?.statusCode,
              !(200..<300).contains(statusCode)
        else { return nil }
        return URLError(.badServerResponse, userInfo: [NSLocalizedDescriptionKey: "HTTP \(statusCode)"])
    }

    @discardableResult
    public class func loadFile(url: URL,
                                progressHandler: ((Progress) -> Void)? = nil,
                                completion: ((_ result: Result<URL, Error>) -> Void)? = nil)
    -> Cancellable? {

        if let path = Components.storage.filePath(for: url) {
            if Thread.isMainThread {
                completion?(.success(.init(fileURLWithPath: path)))
            } else {
                DispatchQueue.main.async {
                    completion?(.success(.init(fileURLWithPath: path)))
                }
            }
            return nil
        }

        let request = URLRequest(url: url)

        return URLSession.shared.downloadTask(with: request) { responseUrl, response, error in
            if let error = error ?? Self.statusError(response) {
                DispatchQueue.main.async {
                    completion?(.failure(error))
                }
            } else if let responseUrl = responseUrl {
                let cachedUrl = Components.storage
                    .storeFile(originalUrl: url,
                               file: responseUrl,
                               deleteFromSrc: true)
                DispatchQueue.main.async {
                    completion?(.success(cachedUrl ?? responseUrl))
                }
            }
        }.start().handleProgress { progress in
            progressHandler?(progress)
        }
    }

    @discardableResult
    public class func loadImage(url: URL,
                                into view: ImagePresentable? = nil,
                                placeholder: UIImage? = nil,
                                progressHandler: ((Progress) -> Void)? = nil,
                                completion: ((_ result: Result<UIImage, Error>) -> Void)? = nil)
    -> Cancellable? {

        func setPlaceholder() {
            if placeholder != nil {
                view?.image = placeholder
            }
        }
        setPlaceholder()
        return loadFile(url: url,
                        progressHandler: progressHandler) { [weak view] result in
            switch result {
            case .success(let url):
                let image = UIImage(contentsOfFile: url.path) ?? UIImage()
                view?.image = image
                completion?(.success(image))
            case .failure(let error):
                setPlaceholder()
                completion?(.failure(error))
            }
        }
    }
}

fileprivate extension URLSessionTask {

    func start() -> Self {
        resume()
        return self
    }

    func handleProgress(_ handle: ((Progress) -> Void)?) -> Self {
        associatedObserverTask = progress.observe(\.fractionCompleted) { progress, _ in
            handle?(progress)
        }
        return self
    }

    static var observerKey: UInt8 = 0

    var associatedObserverTask: AnyObject? {
        get { objc_getAssociatedObject(self, &Self.observerKey) as? AnyObject }
        set { objc_setAssociatedObject(self, &Self.observerKey, newValue, .OBJC_ASSOCIATION_RETAIN) }
    }
}

extension URLSessionTask: Cancellable {

}
