//
//  Loader.swift
//  SceytChatUIKit
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

        return URLSession.shared.downloadTask(with: request) { responseUrl, _, error in
            if let error = error {
                completion?(.failure(error))
            } else if let responseUrl = responseUrl {
                completion?(.success(responseUrl))
            }
        }.start().handleProgress { progress in
            progressHandler?(progress)
        }
    }

    @discardableResult
    public class func loadFile(url: URL,
                                progressHandler: ((Progress) -> Void)? = nil,
                                completion: ((_ result: Result<URL, Error>) -> Void)? = nil)
    -> Cancellable? {

        if let path = Storage.filePath(for: url) {
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

        return URLSession.shared.downloadTask(with: request) { responseUrl, _, error in
            if let error = error {
                DispatchQueue.main.async {
                    completion?(.failure(error))
                }
            } else if let responseUrl = responseUrl {
                let cachedUrl = Storage
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

    static var observerKey: UInt8 = 1

    var associatedObserverTask: AnyObject? {
        get { objc_getAssociatedObject(self, &Self.observerKey) as? AnyObject }
        set { objc_setAssociatedObject(self, &Self.observerKey, newValue, .OBJC_ASSOCIATION_RETAIN) }
    }
}

extension URLSessionTask: Cancellable {

}
