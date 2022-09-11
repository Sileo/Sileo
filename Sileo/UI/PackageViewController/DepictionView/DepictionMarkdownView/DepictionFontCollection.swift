//
//  DepictionFontCollection.swift
//  Sileo
//
//  Created by CoolStar on 11/19/19.
//  Copyright © 2022 Sileo Team. All rights reserved.
//

import Foundation
import Down

public struct DepictionFontCollection: FontCollection {

    public var heading1 = DownFont.boldSystemFont(ofSize: 28)
    public var heading2 = DownFont.boldSystemFont(ofSize: 24)
    public var heading3 = DownFont.boldSystemFont(ofSize: 18)
    public var heading4 = DownFont.boldSystemFont(ofSize: 16)
    public var heading5 = DownFont.boldSystemFont(ofSize: 14)
    public var heading6 = DownFont.boldSystemFont(ofSize: 12)
    public var body = DownFont.systemFont(ofSize: 16)
    public var code = DownFont(name: "menlo", size: 16) ?? .systemFont(ofSize: 16)
    public var listItemPrefix = DownFont.monospacedDigitSystemFont(ofSize: 16, weight: .regular)
}
