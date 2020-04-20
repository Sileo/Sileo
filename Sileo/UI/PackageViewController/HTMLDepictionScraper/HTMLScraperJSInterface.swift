//
//  HTMLScraperJSInterface.swift
//  BigBossHTMLParse
//
//  Created by CoolStar on 8/27/19.
//  Copyright © 2019 CoolStar. All rights reserved.
//

import Foundation
import SwiftSoup
import JavaScriptCore

@objc protocol ScraperElementExports: JSExport {
    func getElement(id: String?) -> ScraperElement?
    func getElements(tag: String?) -> [ScraperElement]
    func getElements(className: String?) -> [ScraperElement]
    func parent() -> ScraperElement?
    func children() -> [ScraperElement]
    func text() -> String?
    func html() -> String?
    func id() -> String?
    func className() -> String?
    func tag() -> String?
    func attr(_ name: String) -> String?
}

@objc public class ScraperElement: NSObject, ScraperElementExports {
    private var rawElement: Element?

    public init(rawElement: Element) {
        self.rawElement = rawElement
        super.init()
    }

    func getElement(id: String?) -> ScraperElement? {
        guard let rawElement = rawElement,
            let id = id,
            let targetRaw = try? rawElement.getElementById(id) else {
            return nil
        }
        return ScraperElement(rawElement: targetRaw)
    }

    func getElements(tag: String?) -> [ScraperElement] {
        guard let rawElement = rawElement,
            let tag = tag,
            let targetsRaw = try? rawElement.getElementsByTag(tag) else {
            return []
        }
        return targetsRaw.map { ScraperElement(rawElement: $0) }
    }

    func getElements(className: String?) -> [ScraperElement] {
        guard let rawElement = rawElement,
            let className = className,
            let targetsRaw = try? rawElement.getElementsByClass(className) else {
            return []
        }
        return targetsRaw.map { ScraperElement(rawElement: $0) }
    }

    func parent() -> ScraperElement? {
        guard let rawElement = rawElement,
            let targetRaw = rawElement.parent() else {
            return nil
        }
        return ScraperElement(rawElement: targetRaw)
    }

    func children() -> [ScraperElement] {
        guard let rawElement = rawElement else {
            return []
        }
        let targetsRaw = rawElement.children()
        return targetsRaw.map { ScraperElement(rawElement: $0) }
    }

    func text() -> String? {
        try? rawElement?.text()
    }

    func html() -> String? {
        try? rawElement?.html()
    }

    func id() -> String? {
        rawElement?.id()
    }

    func className() -> String? {
        try? rawElement?.className()
    }

    func tag() -> String? {
        rawElement?.tagName().lowercased()
    }

    func attr(_ name: String) -> String? {
        try? rawElement?.attr(name)
    }
}
