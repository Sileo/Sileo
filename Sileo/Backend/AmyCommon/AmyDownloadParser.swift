//
//  AmyDownloadParser.swift
//  Sileo
//
//  Created by Amy on 01/05/2021.
//  Copyright © 2021 Amy While. All rights reserved.
//

import Foundation

final class AmyDownloadParser: NSObject, URLSessionDownloadDelegate {
    
    private var request: URLRequest
    private var task: URLSessionDownloadTask?
    private let queue = OperationQueue()
    private var progress = Progress()
    public var progressCallback: ((_ progress: Progress) -> Void)?
    public var didFinishCallback: ((_ status: Int, _ url: URL) -> Void)?
    public var errorCallback: ((_ status: Int, _ error: Error?, _ url: URL?) -> Void)?
    public var url: URL?
    
    struct Progress {
        var period: Int64 = 0
        var total: Int64 = 0
        var expected: Int64 = 0
        var fractionCompleted: Double {
            Double(total) / Double(expected)
        }
    }
    
    init(url: URL, method: String = "GET", headers: [String: String] = [:]) {
        var request = URLRequest(url: url, timeoutInterval: 30)
        request.httpMethod = method
        for (key, value) in headers {
            request.setValue(value, forHTTPHeaderField: key)
        }
        self.request = request
        self.url = url
    }
    
    init(request: URLRequest) {
        self.request = request
        self.url = request.url
    }
    
    public func cancel() {
        task?.cancel()
    }
    
    public func resume() {
        task?.resume()
    }
    
    public func make() {
        let sessionConfig = URLSessionConfiguration.default
        let session = URLSession(configuration: sessionConfig, delegate: self, delegateQueue: queue)
        let task = session.downloadTask(with: request) { url, response, error in
            guard let statusCode = (response as? HTTPURLResponse)?.statusCode else {
                self.errorCallback?(522, error, url)
                return
            }
            guard statusCode == 200,
                  error == nil,
                  let complete = url else {
                self.errorCallback?(statusCode, error, url)
                return
            }
            self.didFinishCallback?(statusCode, complete)
            return
        }
        self.task = task
    }
    
    // Required but unused delegate method
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {}
    
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        self.progress.period = bytesWritten
        self.progress.total = totalBytesWritten
        self.progress.expected = totalBytesExpectedToWrite
        self.progressCallback?(progress)
    }
}
