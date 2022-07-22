//
//  UIPasteboard+Sources.swift
//  Sileo
//
//  Created by CoolStar on 8/4/19.
//  Copyright © 2022 Sileo Team. All rights reserved.
//

import Foundation

extension UIPasteboard {
    func sources() -> [URL] {
        guard let string = self.string else {
            return []
        }
        
        // Split into discrete URLs separated by whitespace, remove empty strings
        let possibleURLs = string.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }
        
        return possibleURLs.compactMap { URL(string: $0) }
    }
    
    func newSources() -> [URL] {
        self.sources().filter {
            if $0.scheme == "https" || $0.scheme == "http" {
                return !RepoManager.shared.hasRepo(with: $0)
            } else {
                return false
            }
        }
    }
}
