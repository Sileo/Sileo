//
//  PaymentError.swift
//  Sileo
//
//  Created by Skitty on 6/29/20.
//  Copyright © 2022 Sileo Team. All rights reserved.
//

import Foundation

class PaymentError: CustomStringConvertible {
    var message: String
    var recoveryURL: URL?
    var shouldInvalidate: Bool
    
    static let invalidResponse = PaymentError(message: String(localizationKey: "Invalid_Payment_Provider_Response", type: .error))
    static let noPaymentProvider = PaymentError(message: String(localizationKey: "No_Payment_Provider", type: .error))
    
    convenience init(error: Error?) {
        self.init(message: error?.localizedDescription)
    }
    
    convenience init(message: String?) {
        self.init(message: message, recoveryURL: nil, shouldInvalidate: false)
    }
    
    init(message: String?, recoveryURL: URL?, shouldInvalidate: Bool) {
        self.message = message ?? String(localizationKey: "Unknown", type: .error)
        self.recoveryURL = recoveryURL
        self.shouldInvalidate = shouldInvalidate
    }
    
    var description: String {
        String(format: "Payment Error: %@", message)
    }
    
    func alert(title: String) -> UIAlertController {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        
        alert.addAction(UIAlertAction(title: String(localizationKey: "OK"), style: .cancel, handler: nil))
        
        if recoveryURL != nil && UIApplication.shared.canOpenURL(recoveryURL!) {
            alert.addAction(UIAlertAction(title: String(localizationKey: "More_Info"), style: .default, handler: { _ in
                UIApplication.shared.open(self.recoveryURL!, options: [:])
            }))
        }
        
        return alert
    }
    
    static func alert(for error: PaymentError?, title: String) -> UIAlertController {
        let err = error ?? PaymentError(message: nil)
        return err.alert(title: title)
    }
}
