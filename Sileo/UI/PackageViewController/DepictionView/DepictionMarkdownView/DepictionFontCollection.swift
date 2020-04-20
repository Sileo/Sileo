//
//  DepictionFontCollection.swift
//  Sileo
//
//  Created by CoolStar on 11/19/19.
//  Copyright © 2019 CoolStar. All rights reserved.
//

import Foundation
import Down

public struct DepictionFontCollection: FontCollection {

    public var heading1 = DownFont.boldSystemFont(ofSize: 28)
    public var heading2 = DownFont.boldSystemFont(ofSize: 24)
    public var heading3 = DownFont.boldSystemFont(ofSize: 18)
    public var body = DownFont.systemFont(ofSize: 16)
    public var code = DownFont(name: "menlo", size: 16) ?? .systemFont(ofSize: 16)
    public var listItemPrefix = DownFont.monospacedDigitSystemFont(ofSize: 16, weight: .regular)
}
