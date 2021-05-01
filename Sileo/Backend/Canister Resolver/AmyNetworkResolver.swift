//
//  AmyNetworkResolver.swift
//  Aemulo
//
//  Created by Amy on 23/03/2021.
//  Copyright © 2021 Amy While. All rights reserved.
//

import UIKit

final class AmyNetworkResolver {
    
    static let shared = AmyNetworkResolver()
    
    var cacheDirectory: URL {
        FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
    }

    init() {
        if !cacheDirectory.dirExists {
            do {
                try FileManager.default.createDirectory(atPath: cacheDirectory.path, withIntermediateDirectories: false, attributes: nil)
            } catch {
                print("Failed to create cache directory \(error.localizedDescription)")
            }
            
        }
        guard let contents = try? FileManager.default.contentsOfDirectory(atPath: cacheDirectory.path),
              !contents.isEmpty else { return }
        var yes = DateComponents()
        yes.day = -7
        let weekOld = Calendar.current.date(byAdding: yes, to: Date()) ?? Date()
        for cached in contents {
            guard let attr = try? FileManager.default.attributesOfItem(atPath: cached),
                  let date = attr[FileAttributeKey.modificationDate] as? Date else { continue }
            if weekOld > date {
                try? FileManager.default.removeItem(atPath: cached)
            }
        }
    }
    
    class public func dict(request: URLRequest, _ completion: @escaping ((_ success: Bool, _ dict: [String: Any]?) -> Void)) {
        AmyNetworkResolver.request(request) { success, data -> Void in
            guard success,
                  let data = data else { return completion(false, nil) }
            do {
                let dict = try JSONSerialization.jsonObject(with: data, options: .mutableContainers) as? [String: Any] ?? [String: Any]()
                return completion(true, dict)
            } catch {}
            return completion(false, nil)
        }
    }
    
    class public func dict(url: String?, method: String = "GET", headers: [String: String] = [:], json: [String: AnyHashable] = [:], _ completion: @escaping ((_ success: Bool, _ dict: [String: Any]?) -> Void)) {
        guard let surl = url,
              let url = URL(string: surl) else { return completion(false, nil) }
        AmyNetworkResolver.dict(url: url, method: method, headers: headers, json: json) { success, dict -> Void in
            return completion(success, dict)
        }
    }
    
    class public func dict(url: URL, method: String = "GET", headers: [String: String] = [:], json: [String: AnyHashable] = [:], _ completion: @escaping ((_ success: Bool, _ dict: [String: Any]?) -> Void)) {
        AmyNetworkResolver.request(url: url, method: method, headers: headers) { success, data in
            guard success,
                  let data = data else { return completion(false, nil) }
            do {
                let dict = try JSONSerialization.jsonObject(with: data, options: .mutableContainers) as? [String: Any] ?? [String: Any]()
                return completion(true, dict)
            } catch {}
            return completion(false, nil)
        }
    }
    
    class public func array(request: URLRequest, _ completion: @escaping ((_ success: Bool, _ array: [[String: Any]]?) -> Void)) {
        AmyNetworkResolver.request(request) { success, data in
            guard success,
                  let data = data else { return completion(false, nil) }
            do {
                let array = try JSONSerialization.jsonObject(with: data, options: .mutableContainers) as? [[String: Any]] ?? [[String: Any]]()
                return completion(true, array)
            } catch {}
            return completion(false, nil)
        }
    }
    
    class public func array(url: String?, method: String = "GET", headers: [String: String] = [:], json: [String: AnyHashable] = [:], _ completion: @escaping ((_ success: Bool, _ array: [[String: Any]]?) -> Void)) {
        guard let surl = url,
              let url = URL(string: surl) else { return completion(false, nil) }
        AmyNetworkResolver.array(url: url, method: method, headers: headers, json: json) { success, array -> Void in
            return completion(success, array)
        }
    }
    
    class public func array(url: URL, method: String = "GET", headers: [String: String] = [:], json: [String: AnyHashable] = [:], _ completion: @escaping ((_ success: Bool, _ array: [[String: Any]]?) -> Void)) {
        AmyNetworkResolver.request(url: url, method: method, headers: headers) { success, data in
            guard success,
                  let data = data else { return completion(false, nil) }
            do {
                let array = try JSONSerialization.jsonObject(with: data, options: .mutableContainers) as? [[String: Any]] ?? [[String: Any]]()
                return completion(true, array)
            } catch {}
            return completion(false, nil)
        }
    }
    
    class private func request(url: URL, method: String = "GET", headers: [String: String] = [:], json: [String: AnyHashable] = [:], _ completion: @escaping ((_ success: Bool, _ data: Data?) -> Void)) {
        var request = URLRequest(url: url, timeoutInterval: 30)
        request.httpMethod = method
        for (key, value) in headers {
            request.setValue(value, forHTTPHeaderField: key)
        }
        if !json.isEmpty,
           let jsonData = try? JSONSerialization.data(withJSONObject: json, options: .prettyPrinted) {
            request.httpBody = jsonData
        }
        let task = URLSession.shared.dataTask(with: request) { data, _, _ -> Void in
            if let data = data {
                return completion(true, data)
            }
            return completion(false, nil)
        }
        task.resume()
    }
    
    class private func request(_ request: URLRequest, _ completion: @escaping ((_ success: Bool, _ data: Data?) -> Void)) {
        let task = URLSession.shared.dataTask(with: request) { data, _, _ -> Void in
            if let data = data {
                return completion(true, data)
            }
            return completion(false, nil)
        }
        task.resume()
    }
    
    internal func image(_ url: String, method: String = "GET", headers: [String: String] = [:], cache: Bool = true, scale: CGFloat? = nil, _ completion: @escaping ((_ refresh: Bool, _ image: UIImage?) -> Void)) -> UIImage? {
        guard let url = URL(string: url) else { completion(false, nil); return nil }
        return self.image(url, method: method, headers: headers, cache: cache, scale: scale) { refresh, image in
            completion(refresh, image)
        }
    }
    
    internal func image(_ url: URL, method: String = "GET", headers: [String: String] = [:], cache: Bool = true, scale: CGFloat? = nil, _ completion: @escaping ((_ refresh: Bool, _ image: UIImage?) -> Void)) -> UIImage? {
        let encoded = url.absoluteString.toBase64
        let path = cacheDirectory.appendingPathComponent("\(encoded).png")
        if path.exists {
            if let data = try? Data(contentsOf: path) {
                if let image = (scale != nil) ? UIImage(data: data, scale: scale!) : UIImage(data: data) {
                    if cache {
                        if let attr = try? FileManager.default.attributesOfItem(atPath: path.path),
                           let date = attr[FileAttributeKey.modificationDate] as? Date {
                            var yes = DateComponents()
                            yes.day = -1
                            let yesterday = Calendar.current.date(byAdding: yes, to: Date()) ?? Date()
                            if date > yesterday {
                                completion(false, image)
                            }
                        }
                    }
                    return image
                }
            }
        }
        
        var request = URLRequest(url: url, timeoutInterval: 30)
        request.httpMethod = method
        for (key, value) in headers {
            request.setValue(value, forHTTPHeaderField: key)
        }
        let task = URLSession.shared.dataTask(with: request) { data, _, _ -> Void in
            if let data = data,
               let image = (scale != nil) ? UIImage(data: data, scale: scale!) : UIImage(data: data) {
                completion(true, image)
                if cache {
                    do {
                        try data.write(to: path)
                    } catch {
                        print("Error saving to \(path.absoluteString) with error: \(error.localizedDescription)")
                    }
                }
            }
            completion(false, nil)
        }
        task.resume()
        return nil
    }
    
    internal func saveCache(_ url: URL, data: Data) {
        let encoded = url.absoluteString.toBase64
        let path = cacheDirectory.appendingPathComponent("\(encoded).png")
        do {
            try data.write(to: path)
        } catch {
            print("Error saving to \(path.absoluteString) with error: \(error.localizedDescription)")
        }
    }
    
    internal func imageCache(_ url: URL, scale: CGFloat? = nil) -> (Bool, UIImage?) {
        let encoded = url.absoluteString.toBase64
        let path = cacheDirectory.appendingPathComponent("\(encoded).png")
        if let data = try? Data(contentsOf: path) {
            if let image = (scale != nil) ? UIImage(data: data, scale: scale!) : UIImage(data: data) {
                if let attr = try? FileManager.default.attributesOfItem(atPath: path.path),
                   let date = attr[FileAttributeKey.modificationDate] as? Date {
                    var yes = DateComponents()
                    yes.day = -1
                    let yesterday = Calendar.current.date(byAdding: yes, to: Date()) ?? Date()
                    if date > yesterday {
                        return (false, image)
                    }
                }
                return (true, image)
            }
        }
        return (true, nil)
    }
}

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

extension String {
    var toBase64: String {
        return Data(self.utf8).base64EncodedString().replacingOccurrences(of: "/", with: "").replacingOccurrences(of: "=", with: "")
    }
}
