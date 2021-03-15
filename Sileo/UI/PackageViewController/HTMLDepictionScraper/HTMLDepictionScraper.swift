//
//  HTMLDepictionScrape.swift
//  BigBossHTMLParse
//
//  Created by CoolStar on 8/27/19.
//  Copyright © 2019 CoolStar. All rights reserved.
//

import Foundation
import SwiftSoup
import JavaScriptCore
import os.log

class HTMLDepictionScraper {
    public func scrapeHTML(url: URL) throws -> String {
        guard let javascriptContext = JSContext() else {
            return ""
        }

        let data = try Data(contentsOf: url)

        guard let html = String(data: data, encoding: .utf8) else {
            return ""
        }

        let debugBlock: @convention(block) (String) -> Void = { string in
            os_log("ScrDbg: %@", string)
        }

        let cleanBlock: @convention(block) (String) -> String = { unsafe in
            let safe = try? SwiftSoup.clean(unsafe, Whitelist.basic())
            let filteredText = safe ?? ""

            let regexDuplLineBreaks = try? NSRegularExpression(pattern: "<br( +|)(\\/|)>(\\s*)<br( +|)(\\/|)>(\\s*)<br( +|)(\\/|)>",
                                                               options: .caseInsensitive)
            let removeDuplicateLineBreaks = regexDuplLineBreaks?.stringByReplacingMatches(in: filteredText,
                                                                                          options: [],
                                                                                          range: NSRange(location: 0,
                                                                                                         length: filteredText.count),
                                                                                          withTemplate: "<br><br>") ?? ""

            let regexEmptyParagraphs = try? NSRegularExpression(pattern: "<p([^>]+|)>(\\s+|)<\\/(\\s+|)p>", options: .caseInsensitive)
            let removeEmptyParagraphs = regexEmptyParagraphs?.stringByReplacingMatches(in: removeDuplicateLineBreaks,
                                                                                       options: [],
                                                                                       range: NSRange(location: 0,
                                                                                                      length: removeDuplicateLineBreaks.count),
                                                                                       withTemplate: "")

            return removeEmptyParagraphs ?? ""
        }

        let absoluteURL: @convention(block) (String) -> String = { relative in
            if relative == "." {
                return url.absoluteString
            }
            let url = URL(string: relative, relativeTo: url)
            return url?.absoluteString ?? ""
        }

        var downloadCount = 0
        let downloadPage: @convention(block) (String, String, String) -> Bool = { urlStr, headName, bodyName in
            if downloadCount >= 10 {
                return false
            }
            guard let url = URL(string: urlStr),
                let data = try? Data(contentsOf: url),
                let html = String(data: data, encoding: .utf8),
                let doc = try? SwiftSoup.parse(html) else {
                return false
            }
            downloadCount += 1
            if let rawHead = doc.head() {
                let head = ScraperElement(rawElement: rawHead)
                javascriptContext.setObject(head, forKeyedSubscript: headName as NSString)
            }
            if let rawBody = doc.body() {
                let body = ScraperElement(rawElement: rawBody)
                javascriptContext.setObject(body, forKeyedSubscript: bodyName as NSString)
            }
            return true
        }

        javascriptContext.setObject(debugBlock, forKeyedSubscript: "print" as NSString)
        javascriptContext.setObject(cleanBlock, forKeyedSubscript: "cleanHTML" as NSString)
        javascriptContext.setObject(absoluteURL, forKeyedSubscript: "absoluteURL" as NSString)
        javascriptContext.setObject(downloadPage, forKeyedSubscript: "downloadPage" as NSString)

        javascriptContext.setObject(html, forKeyedSubscript: "html" as NSString)

        let doc = try SwiftSoup.parse(html, url.absoluteString)

        if let rawHead = doc.head() {
            let head = ScraperElement(rawElement: rawHead)
            javascriptContext.setObject(head, forKeyedSubscript: "head" as NSString)
        }

        if let rawBody = doc.body() {
            let body = ScraperElement(rawElement: rawBody)
            javascriptContext.setObject(body, forKeyedSubscript: "body" as NSString)
        }

        guard let sileoGenJS = try? String(contentsOfFile: Bundle.main.path(forResource: "RepoScraper/SileoGen", ofType: "js") ?? "") else {
            return ""
        }
        javascriptContext.evaluateScript(sileoGenJS)

        var scraperName = ""

        guard let plist = NSDictionary(contentsOfFile: Bundle.main.path(forResource: "RepoScraper/DepictionScrapers.plist",
                                                                        ofType: "") ?? "") as? [String: [[String: String]]] else {
            return ""
        }
        plist.forEach { name, properties in
            for property in properties {
                if let prefix = property["prefix"] {
                    guard url.path.hasPrefix(prefix) else {
                        return
                    }
                }
                if let suffix = property["suffix"] {
                    guard url.path.hasSuffix(suffix) else {
                        return
                    }
                }
                if let refHost = property["host"] {
                    if refHost == url.host {
                        scraperName = name
                        return
                    }
                }
            }
        }

        guard !scraperName.isEmpty,
            let scraperJS = try? String(contentsOfFile: Bundle.main.path(forResource: "RepoScraper/\(scraperName).js", ofType: "") ?? "")else {
            return ""
        }
        if let json = javascriptContext.evaluateScript(scraperJS)?.toString() {
            return json
        }
        return ""
    }
}
