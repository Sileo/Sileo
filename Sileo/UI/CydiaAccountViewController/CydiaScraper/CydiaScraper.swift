//
//  CydiaScraper.swift
//  Sileo
//
//  Created by CoolStar on 4/17/20.
//  Copyright © 2020 CoolStar. All rights reserved.
//

import Foundation
import SwiftSoup

class CydiaScraper {
    static func parsePurchaseList(rawHTML: String) -> [String] {
        var purchasedIds: [String] = []
        do {
            let doc = try SwiftSoup.parse(rawHTML)
            let links = try doc.select("a")
            
            for link in links {
                if let href = try? link.attr("href") {
                    let prefix = "http://cydia.saurik.com/package/"
                    if href.hasPrefix(prefix) {
                        let packageId = String(href.drop(prefix: prefix))
                        purchasedIds.append(packageId)
                    }
                    
                    let prefix2 = "https://cydia.saurik.com/package/"
                    if href.hasPrefix(prefix2) {
                        let packageId = String(href.drop(prefix: prefix2))
                        purchasedIds.append(packageId)
                    }
                }
            }
        } catch {
        }
        return purchasedIds
    }
}
