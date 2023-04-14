//
//  LanguageHelper.swift
//  Sileo
//
//  Created by Andromeda on 03/08/2021.
//  Copyright © 2022 Sileo Team. All rights reserved.
//

import Evander

enum LocalizedStringType {
    case general, error, categories
    
    /// The table name this string type can be found in.
    var tableName: String? {
        switch self {
        case .general: return nil
        case .error: return "Errors"
        case .categories: return "Categories"
        }
    }
}

extension String {
    /// Creates a localized string from the provided key.
    init(localizationKey: String, type: LocalizedStringType = .general) {
        // swiftlint:disable nslocalizedstring_key
        if let bundle = LanguageHelper.shared.primaryBundle {
            self = NSLocalizedString(localizationKey, tableName: type.tableName, bundle: bundle, comment: "")
        } else {
            self = NSLocalizedString(localizationKey, tableName: type.tableName, comment: "")
        }
    }
}
