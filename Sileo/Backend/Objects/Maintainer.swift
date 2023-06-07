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
    let string: String?

    init(string: String?) {
        guard let inputString = string else {
            self.name = nil
            self.email = nil
            self.string = nil
            return
        }
        self.string = string
        if let emailStartIndex = inputString.range(of: "<")?.lowerBound {
            let nameRange = inputString.startIndex..<emailStartIndex
            let name = inputString[nameRange].trimmingCharacters(in: .whitespaces)
            
            if let emailEndIndex = inputString.range(of: ">")?.lowerBound {
                let emailRange = inputString.index(after: emailStartIndex)..<emailEndIndex
                let email = inputString[emailRange].lowercased()
                
                self.name = name.isEmpty ? nil : name
                self.email = email.isEmpty ? nil : email
            } else {
                self.name = name.isEmpty ? nil : name
                self.email = nil
            }
        } else {
            self.name = inputString.isEmpty ? nil : inputString
            self.email = nil
        }
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let stringValue = try? container.decode(String.self)
        self.init(string: stringValue)
    }
    
}
