//
//  DepictionColorCollection.swift
//  Sileo
//
//  Created by CoolStar on 11/19/19.
//  Copyright © 2022 Sileo Team. All rights reserved.
//

import Foundation
import Down

public struct DepictionColorCollection: ColorCollection {

    public var heading1 = DownColor.sileoLabel
    public var heading2 = DownColor.sileoLabel
    public var heading3 = DownColor.sileoLabel
    public var heading4 = DownColor.sileoLabel
    public var heading5 = DownColor.sileoLabel
    public var heading6 = DownColor.sileoLabel
    public var body = DownColor.sileoLabel
    public var code = DownColor.sileoLabel
    public var link = DownColor.systemBlue
    public var quote = DownColor.darkGray
    public var quoteStripe = DownColor.darkGray
    public var thematicBreak = DownColor(white: 0.9, alpha: 1)
    public var listItemPrefix = DownColor.lightGray
    public var codeBlockBackground = DownColor(red: 0.96, green: 0.97, blue: 0.98, alpha: 1)
}
