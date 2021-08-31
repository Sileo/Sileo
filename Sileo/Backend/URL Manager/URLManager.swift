//
//  URLManager.swift
//  Sileo
//
//  Created by CoolStar on 4/20/20.
//  Copyright © 2020 Sileo Team. All rights reserved.
//

import Foundation
import SafariServices

class URLManager {
    static func url(package: String) -> String {
        "sileo://package/" + package
    }
    
    static func urlRequest(_ url: URL, includingDeviceInfo: Bool = true) -> URLRequest {
        var request = URLRequest(url: url, cachePolicy: .useProtocolCachePolicy, timeoutInterval: 5)
        
        let cfVersion = String(format: "%.3f", kCFCoreFoundationVersionNumber)
        let bundleName = Bundle.main.infoDictionary?[kCFBundleNameKey as String] ?? ""
        let bundleVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] ?? ""
        let osType = UIDevice.current.kernOSType
        let osRelease = UIDevice.current.kernOSRelease
        request.setValue("\(bundleName)/\(bundleVersion) CoreFoundation/\(cfVersion) \(osType)/\(osRelease)", forHTTPHeaderField: "User-Agent")
        
        if includingDeviceInfo {
            request.setValue(UIDevice.current.platform, forHTTPHeaderField: "X-Machine")
            request.setValue(UIDevice.current.uniqueIdentifier, forHTTPHeaderField: "X-Unique-ID")
            request.setValue(UIDevice.current.systemVersion, forHTTPHeaderField: "X-Firmware")
        }
        return request
    }
    
    static func viewController(url: URL?, isExternalOpen: Bool, presentModally: inout Bool) -> UIViewController? {
        guard let url = url else {
            return nil
        }
        
        presentModally = false
        
        if url.scheme == "http" || url.scheme == "https" {
            presentModally = true
            let viewController = SFSafariViewController(url: url)
            viewController.preferredControlTintColor = UINavigationBar.appearance().tintColor
            return viewController
        } else if url.scheme == "sileo" {
            if url.host == "package" && url.pathComponents.count >= 2 {
                if let package = PackageListManager.shared.newestPackage(identifier: url.pathComponents[1], repoContext: nil) {
                    let packageVC = NativePackageViewController.viewController(for: package)
                    return isExternalOpen ? UINavigationController(rootViewController: packageVC) : packageVC
                } else {
                    presentModally = true
                    let alertController = UIAlertController(title: String(format: String(localizationKey: "No_Package.Title",
                                                                                         type: .error), url.pathComponents[1]),
                                                            message: String(localizationKey: "No_Package.Body", type: .error),
                                                            preferredStyle: .alert)
                    alertController.addAction(UIAlertAction(title: String(localizationKey: "OK"), style: .cancel, handler: nil))
                    return alertController
                }
            } else if url.host == "url" && url.absoluteString.count >= 12 {
                presentModally = true
                var realURLStr = url.absoluteString
                realURLStr.removeFirst(12)
                if let realURL = URL(string: String(realURLStr)),
                    realURL.scheme == "http" || realURL.scheme == "https" {
                    let viewController = SFSafariViewController(url: realURL)
                    viewController.preferredControlTintColor = UINavigationBar.appearance().tintColor
                    return viewController
                }
            } else if url.host == nil {
                return nil
            }
        }
        presentModally = true
        let alertController = UIAlertController(title: String(localizationKey: "Invalid_URL.Title", type: .error),
                                                message: nil,
                                                preferredStyle: .alert)
        alertController.addAction(UIAlertAction(title: String(localizationKey: "OK"), style: .cancel, handler: nil))
        return alertController
    }
}
