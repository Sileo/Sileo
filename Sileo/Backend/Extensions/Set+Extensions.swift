//
//  Set+Extensions.swift
//  Sileo
//
//  Created by Amy While on 21/07/2022.
//  Copyright © 2022 Sileo Team. All rights reserved.
//

import Foundation

extension Set {
    
    public mutating func removeAll(_ element: @escaping (Element) -> Bool) {
        while let index = first(where: element) {
            remove(index)
        }
    }
    
}
