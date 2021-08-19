//
//  NewsArticle.swift
//  Sileo
//
//  Created by CoolStar on 8/17/20.
//  Copyright © 2020 Sileo Team. All rights reserved.
//

import Foundation

class NewsArticle {
    static let iso8601DateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZ"
        return formatter
    }()
    
    public var guid: String
    public var title: String
    public var body: String
    public var type: String
    public var author: String?
    public var url: URL
    public var imageURL: URL?
    public var date: Date
    public var firstSeenDate: Date?
    public var userReadDate: Date?
    
    init?(dict: [String: String?]) {
        guard let title = dict["title"] as? String,
            let body = dict["excerpt"] as? String,
            let type = dict["type"] as? String,
            let urlStr = dict["url"] as? String,
            let url = URL(string: urlStr),
            let dateStr = dict["date"] as? String,
            let date = NewsArticle.iso8601DateFormatter.date(from: dateStr) else {
                return nil
        }
        
        let guid = dict["guid"] as? String ?? "\(dateStr)-\(urlStr)"
        
        self.guid = guid
        self.title = title
        self.body = body
        self.type = type
        self.author = dict["author"] as? String
        self.url = url
        self.imageURL = URL(string: dict["image"] as? String ?? "")
        self.date = date
    }
}
