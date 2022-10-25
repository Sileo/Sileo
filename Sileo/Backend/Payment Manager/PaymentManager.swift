//
//  PaymentManager.swift
//  Sileo
//
//  Created by Skitty on 6/29/20.
//  Copyright © 2022 Sileo Team. All rights reserved.
//

import Foundation

class PaymentManager {
    static let shared = PaymentManager()
    
    var paymentProvidersForURL = [String: PaymentProvider]()
    var paymentProvidersForEndpoint = [String: PaymentProvider]()
    
    func removeProviders(for repo: Repo) {
        print("Providers for URL = \(paymentProvidersForURL)\nProviders for Endpoint = \(paymentProvidersForEndpoint)\nDownload Provider = \(DownloadManager.shared.repoDownloadOverrideProviders)")
        guard let sourceRepo = repo.url?.absoluteString.lowercased() else { return }
        if let provider = paymentProvidersForURL[sourceRepo] {
            paymentProvidersForURL[sourceRepo] = nil
            paymentProvidersForEndpoint[provider.baseURL.absoluteString] = nil
        }
        DownloadManager.shared.repoDownloadOverrideProviders[sourceRepo] = nil
    }
    
    func getAllPaymentProviders(completion: @escaping (Set<PaymentProvider>) -> Void) {
        let group = DispatchGroup()
        var providers = Set<PaymentProvider>()
        for repo in RepoManager.shared.repoList {
            group.enter()
            getPaymentProvider(for: repo) { _, provider in
                if provider != nil && provider!.baseURL.isSecure {
                    providers.insert(provider!)
                }
                group.leave()
            }
        }
        group.notify(queue: .main) {
            completion(providers)
        }
    }
    
    func getPaymentProvider(for repo: Repo, completion: @escaping (PaymentError?, PaymentProvider?) -> Void) {
        guard let sourceRepo = repo.url?.absoluteString.lowercased() else {
            return completion(PaymentError(message: nil), nil)
        }

        // If we already have this provider, return it
        if paymentProvidersForURL[sourceRepo] != nil {
            return completion(nil, paymentProvidersForURL[sourceRepo])
        }
        
        guard let requestURL = repo.url?.appendingPathComponent("payment_endpoint") else {
            return completion(PaymentError(message: nil), nil)
        }
        let request = URLManager.urlRequest(requestURL, includingDeviceInfo: false)
        
        URLSession.shared.dataTask(with: request) { data, _, error in
            // The `error` object here is almost always nil.
            // Consider using the TBURLRequestOptions pod
            guard error == nil,
                let data = data else {
                    return completion(PaymentError(error: error), nil)
            }
            // Decode response
            guard var endpoint = String(data: data, encoding: .utf8) else {
                return completion(PaymentError.noPaymentProvider, nil)
            }
            endpoint = endpoint.trimmingCharacters(in: .whitespacesAndNewlines)
            if endpoint.last != "/" {
                endpoint += "/"
            }
            guard let endpointURL = URL(string: endpoint),
                endpointURL.isSecure else {
                    return completion(PaymentError.noPaymentProvider, nil)
            }
            
            // If we have an old payment provider for this repo, deregister it from the DownloadManager
            if self.paymentProvidersForURL[sourceRepo] != nil {
                DownloadManager.shared.deregister(downloadOverrideProvider: self.paymentProvidersForURL[sourceRepo]!, repo: repo)
            }
            
            let provider = self.paymentProvidersForEndpoint[endpointURL.absoluteString] ?? PaymentProvider(baseURL: endpointURL, repoURL: repo.rawURL)
            self.paymentProvidersForEndpoint[endpointURL.absoluteString] = provider
            self.paymentProvidersForURL[sourceRepo] = provider
            DownloadManager.shared.register(downloadOverrideProvider: provider, repo: repo)
            
            completion(nil, self.paymentProvidersForURL[sourceRepo])
        }.resume()
    }
    
    func getPaymentProvider(for endpoint: String) -> PaymentProvider? {
        paymentProvidersForEndpoint.first(where: { key, _ in endpoint.hasPrefix(key) })?.value
    }
}
