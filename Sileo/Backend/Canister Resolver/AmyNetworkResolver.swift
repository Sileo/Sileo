//
//  AmyNetworkResolver.swift
//  Sileo
//
//  Created by Amy on 23/03/2021.
//  Copyright © 2021 CoolStar. All rights reserved.
//

import Foundation

internal typealias AmyCompletion = (_ success: Bool, _ dict: [String: Any]?) -> Void

final class AmyNetworkResolver {
    class internal func request(url: String?, method: String = "GET", headers: [String: String] = [:], _ completion: @escaping AmyCompletion) {
        guard let surl = url,
              let url = URL(string: surl) else { return completion(false, nil) }
        AmyNetworkResolver.request(url: url, method: method, headers: headers) { success, dict -> Void in
            return completion(success, dict)
        }
    }
    
    class internal func request(url: URL, method: String = "GET", headers: [String: String] = [:], _ completion: @escaping AmyCompletion) {
        var request = URLRequest(url: url, timeoutInterval: 30)
        request.httpMethod = method
        for (key, value) in headers {
            request.setValue(value, forHTTPHeaderField: key)
        }
        let task = URLSession.shared.dataTask(with: request) { data, _, _ -> Void in
            if let data = data {
                do {
                    let dict = try JSONSerialization.jsonObject(with: data, options: .mutableContainers) as? [String: Any] ?? [String: Any]()
                    return completion(true, dict)
                } catch {}
            }
            return completion(false, nil)
        }
        task.resume()
    }
}
