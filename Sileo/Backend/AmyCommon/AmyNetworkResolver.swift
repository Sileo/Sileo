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
        FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0].appendingPathComponent("AmyCache")
    }
    
    var downloadCache: URL {
        FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0].appendingPathComponent("AmyCache").appendingPathExtension("DownloadCache")
    }

    init() {
        if !cacheDirectory.dirExists {
            do {
                try FileManager.default.createDirectory(atPath: cacheDirectory.path, withIntermediateDirectories: false, attributes: nil)
            } catch {
                print("Failed to create cache directory \(error.localizedDescription)")
            }
            
        }
        if !downloadCache.dirExists {
            do {
                try FileManager.default.createDirectory(atPath: downloadCache.path, withIntermediateDirectories: false, attributes: nil)
            } catch {
                print("Failed to create cache directory \(error.localizedDescription)")
            }
            
        }
        if let contents = try? FileManager.default.contentsOfDirectory(atPath: cacheDirectory.path),
           !contents.isEmpty {
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
        
        if !downloadCache.dirExists {
            do {
                try FileManager.default.createDirectory(atPath: downloadCache.path, withIntermediateDirectories: false, attributes: nil)
            } catch {
                print("Failed to create cache directory \(error.localizedDescription)")
            }
        }
        if let contents = try? FileManager.default.contentsOfDirectory(atPath: downloadCache.path),
           !contents.isEmpty {
            var yes = DateComponents()
            yes.hour = -1
            let hourOld = Calendar.current.date(byAdding: yes, to: Date()) ?? Date()
            for cached in contents {
                guard let attr = try? FileManager.default.attributesOfItem(atPath: cached),
                      let date = attr[FileAttributeKey.modificationDate] as? Date else { continue }
                if hourOld > date {
                    try? FileManager.default.removeItem(atPath: cached)
                }
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
        AmyNetworkResolver.request(url: url, method: method, headers: headers, json: json) { success, data in
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
        AmyNetworkResolver.request(url: url, method: method, headers: headers, json: json) { success, data in
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
            request.setValue("application/json;charset=utf-8", forHTTPHeaderField: "Content-Type")
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
        var pastData: Data?
        let encoded = url.absoluteString.toBase64
        let path = cacheDirectory.appendingPathComponent("\(encoded).png")
        if path.exists {
            if let data = try? Data(contentsOf: path) {
                if let image = (scale != nil) ? UIImage(data: data, scale: scale!) : UIImage(data: data) {
                    if cache {
                        pastData = data
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
                completion(pastData != data, image)
                if cache {
                    do {
                        try data.write(to: path, options: .atomic)
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
            try data.write(to: path, options: .atomic)
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

extension String {
    var toBase64: String {
        return Data(self.utf8).base64EncodedString().replacingOccurrences(of: "/", with: "").replacingOccurrences(of: "=", with: "")
    }
}
