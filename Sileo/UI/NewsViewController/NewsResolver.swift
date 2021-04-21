//
//  NewsResolver.swift
//  Sileo
//
//  Created by Andromeda on 18/04/2021.
//  Copyright © 2021 CoolStar. All rights reserved.
//

import Foundation

class NewsResolver {
    
    static let shared = NewsResolver()
    public var articles = [NewsArticle]()
    public var showNews = false
    
    init() {
        self.getArticles()
    }
    
    public func getArticles() {
        if !articles.isEmpty { return }
        AmyNetworkResolver.dict(url: "https://getsileo.app/api/new.json") { success, dict in
            guard success,
                  let dict = dict,
                  let articles = dict["articles"] as? [[String: String?]] else {
                    return
            }
            for articleDict in articles {
                if let article = NewsArticle(dict: articleDict) {
                    self.articles.append(article)
                }
            }
            
            var tma = DateComponents()
            tma.month = -3
            let threeMonthsAgo = Calendar.current.date(byAdding: tma, to: Date()) ?? Date()
            self.articles = self.articles.filter({ $0.date > threeMonthsAgo })
            
            var twa = DateComponents()
            twa.day = -14
            let twoWeeksAgo = Calendar.current.date(byAdding: twa, to: Date()) ?? Date()
            let shouldShow = self.articles.contains(where: { $0.date > twoWeeksAgo })
            if shouldShow {
                DispatchQueue.main.async {
                    self.showNews = true
                    NotificationCenter.default.post(name: NewsResolver.ShowNews, object: nil)
                }
            }
        }
    }
    
    static let ShowNews = Notification.Name("Sileo.ShowNews")
}
