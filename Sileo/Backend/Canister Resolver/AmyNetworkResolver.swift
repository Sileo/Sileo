//
//  AmyNetworkResolver.swift
//  Sileo
//
//  Created by Amy on 23/03/2021.
//  Copyright © 2021 CoolStar. All rights reserved.
//

import Foundation

internal typealias AmyCompletion = (_ success: Bool, _ dict: [String : Any]?) -> Void

final class AmyNetworkResolver {
    class internal func request(url: String?, method: String, _ completion: @escaping AmyCompletion) {
        guard let surl = url,
              let url = URL(string: surl) else { return completion(false, nil) }
        var request = URLRequest(url: url)
        request.httpMethod = method
        let task = URLSession.shared.dataTask(with: request) { data, _, error -> Void in
            if let data = data {
                do {
                    let dict = try JSONSerialization.jsonObject(with: data, options: .mutableContainers) as? [String : Any] ?? [String : Any]()
                    completion(true, dict)
                } catch {}
            }
            return completion(false, nil)
        }
        task.resume()
    }
}
