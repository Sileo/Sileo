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
    private var killed = false
    public var progressCallback: ((_ progress: Progress) -> Void)?
    public var didFinishCallback: ((_ status: Int, _ url: URL) -> Void)?
    public var errorCallback: ((_ status: Int, _ error: Error?, _ url: URL?) -> Void)?
    public var waitingCallback: ((_ message: String) -> Void)?
    public var url: URL? {
        request.url
    }
    
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
    }
    
    init(request: URLRequest) {
        self.request = request
    }
    
    public func cancel() {
        killed = true
        task?.cancel()
    }
    
    public func resume() {
        task?.resume()
    }
    
    public func make() {
        let sessionConfig = URLSessionConfiguration.default
        let session = URLSession(configuration: sessionConfig, delegate: self, delegateQueue: queue)
        let task = session.downloadTask(with: request)
        self.task = task
    }
    
    // The Download Finished
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        let filename = location.lastPathComponent,
            destination = AmyNetworkResolver.shared.downloadCache.appendingPathComponent(filename)
        do {
            if FileManager.default.fileExists(atPath: destination.path) {
                try FileManager.default.removeItem(at: destination)
            }
            try FileManager.default.moveItem(at: location, to: destination)
        } catch {
            self.errorCallback?(522, error, destination)
        }

        if let response = downloadTask.response,
           let statusCode = (response as? HTTPURLResponse)?.statusCode {
            if statusCode == 200 {
                self.didFinishCallback?(statusCode, destination)
            } else {
                self.errorCallback?(statusCode, nil, destination)
            }
            return
        }
        if !killed {
            self.errorCallback?(522, nil, destination)
        }
    }
    
    // The Download has made Progress
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        self.progress.period = bytesWritten
        self.progress.total = totalBytesWritten
        self.progress.expected = totalBytesExpectedToWrite
        self.progressCallback?(progress)
    }
    
    // Checking for errors in the download
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if let error = error {
            let statusCode = (task.response as? HTTPURLResponse)?.statusCode ?? 522
            self.errorCallback?(statusCode, error, nil)
        }
    }
    
    // Tell the caller that the download is waiting for network
    func urlSession(_ session: URLSession, taskIsWaitingForConnectivity task: URLSessionTask) {
        self.waitingCallback?("Waiting For Connection")
    }
}
