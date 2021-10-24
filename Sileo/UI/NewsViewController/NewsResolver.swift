//
//  NewsResolver.swift
//  Sileo
//
//  Created by Amy on 18/04/2021.
//  Copyright © 2021 Amy While. All rights reserved.
//

import Foundation
import Evander

class NewsResolver {
    
    static let shared = NewsResolver()
    public var articles = [NewsArticle]()
    public var showNews = false
    
    init() {
        self.getArticles()
    }
    
    public func getArticles() {
        if !articles.isEmpty { return }
        EvanderNetworking.request(url: "https://getsileo.app/api/new.json", type: [String: Any].self) { [weak self] success, _, _, dict in
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
            
            strong.articles = strong.articles.filter({ $0.date > Date(timeIntervalSince1970: Date().timeIntervalSince1970 - 7890000 ) })
            let shouldShow = strong.articles.contains(where: { $0.date > Date(timeIntervalSince1970: Date().timeIntervalSince1970 - 1209600 ) })
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
