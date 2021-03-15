//
//  String+Error.swift
//  Sileo
//
//  Created by CoolStar on 4/19/20.
//  Copyright © 2020 CoolStar. All rights reserved.
//

import Foundation

extension String: LocalizedError {
    public var errorDescription: String? { self }
}
