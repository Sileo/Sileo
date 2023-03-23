//
//  Maintainer.swift
//  Sileo
//
//  Created by Amy While on 23/03/2023.
//  Copyright © 2023 Sileo Team. All rights reserved.
//

import Foundation

struct Maintainer: Decodable {
    
    let name: String?
    let email: String?
    
    init(string: String?) {
        guard var string else {
            self.name = nil
            self.email = nil
            return
        }
        if let range = string.range(of: "<") {
            var name = string[string.startIndex..<range.lowerBound]
            if name.last == " " {
                name.removeLast()
            }
            string.removeSubrange(string.startIndex..<range.lowerBound)
            string.removeFirst()
            if let endRange = string.range(of: ">") {
                let email = string[string.startIndex..<endRange.lowerBound]
                self.email = String(email).lowercased()
            } else {
                self.email = nil
            }
            self.name = String(name)
        } else {
            self.name = string
            self.email = nil
        }
    }
    
    init(from decoder: Decoder) throws {
        guard let container = try? decoder.singleValueContainer(),
              let str = try? container.decode(String.self) else {
            self.init(string: nil)
            return
        }
        self.init(string: str)
    }
    
}
