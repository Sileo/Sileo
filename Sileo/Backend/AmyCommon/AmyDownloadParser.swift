//
//  AmyDownloadParser.swift
//  Sileo
//
//  Created by Amy on 01/05/2021.
//  Copyright © 2021 Amy While. All rights reserved.
//

import Foundation

final class AmyDownloadParser: NSObject {
    
    static let sessionManager: URLSession = {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 30
        return URLSession(configuration: configuration, delegate: AmyDownloadParserDelegate.shared, delegateQueue: OperationQueue())
    }()
    
    static let config = URLSessionConfiguration.default
    
    private var request: URLRequest
    private var task: URLSessionDownloadTask?
    private let queue = OperationQueue()
    private var progress = Progress()
    private var killed = false
    
    public var progressCallback: ((_ progress: Progress) -> Void)? {
        didSet {
            guard var container = container else { return }
            container.progressCallback = progressCallback
            AmyDownloadParserDelegate.shared.update(container)
        }
    }
    public var didFinishCallback: ((_ status: Int, _ url: URL) -> Void)? {
        didSet {
            guard var container = container else { return }
            container.didFinishCallback = didFinishCallback
            AmyDownloadParserDelegate.shared.update(container)
        }
    }
    public var errorCallback: ((_ status: Int, _ error: Error?, _ url: URL?) -> Void)? {
        didSet {
            guard var container = container else { return }
            container.errorCallback = errorCallback
            AmyDownloadParserDelegate.shared.update(container)
        }
    }
    public var waitingCallback: ((_ message: String) -> Void)? {
        didSet {
            guard var container = container else { return }
            container.waitingCallback = waitingCallback
            AmyDownloadParserDelegate.shared.update(container)
        }
    }

    public var url: URL? { request.url }
    public var hasRetried = false
    public var container: AmyDownloadParserContainer? {
        AmyDownloadParserDelegate.shared.container(url)
    }
    public var resumeData: Data? {
        container?.resumeData
    }
    public var shouldResume: Bool {
        container?.shouldResume ?? false
    }
    
    init(url: URL, method: String = "GET", headers: [String: String] = [:]) {
        var request = URLRequest(url: url, timeoutInterval: 5)
        request.httpMethod = method
        for (key, value) in headers {
            request.setValue(value, forHTTPHeaderField: key)
        }
        self.request = request
        super.init()
        let container = AmyDownloadParserContainer(url: url) { [weak self] request in
            guard let strong = self else { return }
            strong.request = request
            strong.resume()
        }
        AmyDownloadParserDelegate.shared.addContainer(container)
    }
    
    init?(request: URLRequest) {
        self.request = request
        guard let url = request.url else { return nil }
        super.init()
        let container = AmyDownloadParserContainer(url: url) { [weak self] request in
            guard let strong = self else { return }
            strong.request = request
            strong.resume()
        }
        AmyDownloadParserDelegate.shared.addContainer(container)
    }
    
    public func cancel() {
        killed = true
        task?.cancel()
        AmyDownloadParserDelegate.shared.remove(container)
    }
    
    public func resume() {
        task?.resume()
    }
    
    public func setShouldResume(_ should: Bool) {
        guard var container = container else { return }
        container.shouldResume = should
        AmyDownloadParserDelegate.shared.update(container)
    }
    
    public func retry() -> Bool {
        guard let container = container,
              container.shouldResume,
              let resumeData = container.resumeData else { return false }
        let task = AmyDownloadParser.sessionManager.downloadTask(withResumeData: resumeData)
        self.task = task
        hasRetried = true
        return true
    }
    
    public func make() {
        let task = AmyDownloadParser.sessionManager.downloadTask(with: request)
        self.task = task
    }
    
}

final class AmyDownloadParserDelegate: NSObject, URLSessionDownloadDelegate {
    static let shared = AmyDownloadParserDelegate()
    public var containers = [URL: AmyDownloadParserContainer]()
    private let queue = DispatchQueue(label: "AmyDownloadParserDelegate.ContainerQueue", attributes: .concurrent)
    
    public func container(_ url: URL?) -> AmyDownloadParserContainer? {
        guard let url = url else { return nil }
        var container: AmyDownloadParserContainer?
        queue.sync { [self] in
            container = containers[url]
        }
        return container
    }

    public func addContainer(_ container: AmyDownloadParserContainer) {
        queue.async(flags: .barrier) { [self] in
            containers[container.url] = container
        }
    }
    
    public func update(_ container: AmyDownloadParserContainer, newRequest: URLRequest? = nil) {
        queue.async(flags: .barrier) { [self] in
            var container = container
            let oldUrl = container.url
            let newUrl = newRequest?.url ?? oldUrl
            container.url = newUrl
            containers.removeValue(forKey: oldUrl)
            containers[newUrl] = container
            if let request = newRequest {
                container.urlChange(request)
            }
        }
    }
    
    public func remove(_ container: AmyDownloadParserContainer?) {
        queue.async(flags: .barrier) { [self] in
            guard let container = container else { return }
            containers.removeValue(forKey: container.url)
        }
    }
    
    public func terminate(_ url: URL) {
        queue.sync { [self] in
            containers[url]?.toBeTerminated = true
        }
    }
    
    // The Download Finished
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        guard let container = container(downloadTask.response?.url ?? downloadTask.currentRequest?.url) else { return }
        if container.toBeTerminated {
            remove(container)
            downloadTask.cancel()
            return
        }
        let filename = location.lastPathComponent,
            destination = AmyNetworkResolver.shared.downloadCache.appendingPathComponent(filename)
        do {
            if FileManager.default.fileExists(atPath: destination.path) {
                try FileManager.default.removeItem(at: destination)
            }
            try FileManager.default.moveItem(at: location, to: destination)
        } catch {
            container.errorCallback?(522, error, destination)
        }

        if let response = downloadTask.response,
           let statusCode = (response as? HTTPURLResponse)?.statusCode {
            if statusCode == 200 || statusCode == 206 { // 206 means partial data, APT handles it fine
                container.didFinishCallback?(statusCode, destination)
            } else {
                container.errorCallback?(statusCode, nil, destination)
                remove(container)
            }
            return
        }
        if !container.killed {
            container.errorCallback?(522, nil, destination)
        }
    }
    
    // The Download has made Progress
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        guard var container = container(downloadTask.response?.url) else {
            return
        }
        if container.toBeTerminated {
            remove(container)
            downloadTask.cancel()
            return
        }
        container.progress.period = bytesWritten
        container.progress.total = totalBytesWritten
        container.progress.expected = totalBytesExpectedToWrite
        container.progressCallback?(container.progress)
        update(container)
    }
    
    // Checking for errors in the download
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        guard var container = container(task.response?.url ?? task.currentRequest?.url) else { return }
        if container.toBeTerminated {
            remove(container)
            return
        }
        if let error = error {
            if (error as NSError).code == NSURLErrorCancelled || (error as NSError).code == NSFileWriteOutOfSpaceError { return }
            container.shouldResume = true
            if container.shouldResume {
                let userInfo = (error as NSError).userInfo
                if let resumeData = userInfo[NSURLSessionDownloadTaskResumeData] as? Data {
                    container.resumeData = resumeData
                    update(container)
                }
            }
            let statusCode = (task.response as? HTTPURLResponse)?.statusCode ?? 522
            container.errorCallback?(statusCode, error, nil)
        }
    }
    
    // Tell the caller that the download is waiting for network
    func urlSession(_ session: URLSession, taskIsWaitingForConnectivity task: URLSessionTask) {
        guard let container = container(task.response?.url) else { return }
        container.waitingCallback?("Waiting For Connection")
    }
    
    // The Download started again with some progress
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didResumeAtOffset fileOffset: Int64, expectedTotalBytes: Int64) {
        guard var container = container(downloadTask.response?.url) else { return }
        if container.toBeTerminated {
            remove(container)
            downloadTask.cancel()
            return
        }
        container.progress.period = 0
        container.progress.total = fileOffset
        container.progress.expected = expectedTotalBytes
        update(container)
        container.progressCallback?(container.progress)
    }
    
    func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse, newRequest request: URLRequest, completionHandler: @escaping (URLRequest?) -> Void) {
        guard let container = container(task.currentRequest?.url) else { return }
        update(container, newRequest: request)
        completionHandler(request)
    }
}

struct AmyDownloadParserContainer {
    public var url: URL
    public var progress = Progress()
    public var killed = false
    public var shouldResume = false
    public var resumeData: Data?
    public var progressCallback: ((_ progress: Progress) -> Void)?
    public var didFinishCallback: ((_ status: Int, _ url: URL) -> Void)?
    public var errorCallback: ((_ status: Int, _ error: Error?, _ url: URL?) -> Void)?
    public var waitingCallback: ((_ message: String) -> Void)?
    public var urlChange: ((_ request: URLRequest) -> Void)
    
    public var toBeTerminated = false
}

struct Progress {
    var period: Int64 = 0
    var total: Int64 = 0
    var expected: Int64 = 0
    var fractionCompleted: Double {
        Double(total) / Double(expected)
    }
}
