//
//  PaymentPackageInfo.swift
//  Sileo
//
//  Created by Skitty on 6/29/20.
//  Copyright © 2022 Sileo Team. All rights reserved.
//

import Foundation

class PaymentPackageInfo {
    var price: String
    var purchased: Bool
    var available: Bool
    
    convenience init?(dictionary: [String: Any]) {
        guard let price = dictionary["price"] as? String,
            let purchasedNum = dictionary["purchased"] as? Int,
            let availableNum = dictionary["available"] as? Int else {
                return nil
        }
        self.init(price: price, purchased: purchasedNum != 0, available: availableNum != 0)
    }
    
    init(price: String, purchased: Bool, available: Bool) {
        self.price = price
        self.purchased = purchased
        self.available = available
    }
    
    var description: String {
        String(format: "Payment Package Info: %@ (%@purchased) (%@available)", price, purchased ? "" : "not", available ? "" : "un")
    }
}
