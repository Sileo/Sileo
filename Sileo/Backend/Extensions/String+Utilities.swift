//
//  String+Utilities.swift
//  Sileo
//
//  Created by CoolStar on 6/23/19.
//  Copyright © 2022 Sileo Team. All rights reserved.
//

import Foundation

extension String {

    func trimmingLeadingWhitespace() -> String {
        self.replacingOccurrences(of: "^\\s+", with: "", options: .regularExpression)
    }

    func drop(prefix: String) -> Substring {
        guard hasPrefix(prefix) else { return Substring(self) }
        return dropFirst(prefix.count)
    }

}
