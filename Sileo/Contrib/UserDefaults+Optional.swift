//
//  UserDefaults+Optional.swift
//  Sileo
//
//  Created by Amy on 20/03/2021.
//  Copyright © 2021 CoolStar. All rights reserved.
//

import Foundation

extension UserDefaults {
    
    func optionalBool(_ key: String, fallback: Bool) -> Bool {
        self.object(forKey: key) as? Bool ?? fallback
    }
    
}
