//
//  NewsResolver.swift
//  Sileo
//
//  Created by Amy on 18/04/2021.
//  Copyright © 2021 Amy While. All rights reserved.
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
        AmyNetworkResolver.dict(url: "https://getsileo.app/api/new.json") { [weak self] success, dict in
            guard success,
                  let strong = self,
                  let dict = dict,
                  let articles = dict["articles"] as? [[String: String?]] else {
                    return
            }
            for articleDict in articles {
                if let article = NewsArticle(dict: articleDict) {
                    if !strong.articles.contains(where: { $0.url == article.url }) {
                        strong.articles.append(article)
                    }
                }
            }
            
            var tma = DateComponents()
            tma.month = -3
            let threeMonthsAgo = Calendar.current.date(byAdding: tma, to: Date()) ?? Date()
            strong.articles = strong.articles.filter({ $0.date > threeMonthsAgo })
            
            var twa = DateComponents()
            twa.day = -14
            let twoWeeksAgo = Calendar.current.date(byAdding: twa, to: Date()) ?? Date()
            let shouldShow = strong.articles.contains(where: { $0.date > twoWeeksAgo })
            if shouldShow {
                DispatchQueue.main.async {
                    strong.showNews = true
                    NotificationCenter.default.post(name: NewsResolver.ShowNews, object: nil)
                }
            }
        }
    }
    
    static let ShowNews = Notification.Name("Sileo.ShowNews")
}
