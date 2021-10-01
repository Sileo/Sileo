//
//  KeychainManager.swift
//  Sileo
//
//  Created by Amy on 14/06/2021.
//  Copyright © 2021 Sileo Team. All rights reserved.
//

import Foundation
import Security
import LocalAuthentication

final class KeychainManager {
    
    static let shared = KeychainManager()
    let accessGroup = "org.coolstar.Sileo"
    
    enum SileoService: String, CaseIterable {
        case secret = "SileoPaymentSecret"
        case token = "SileoPaymentToken"
    }

    private var accessControl: SecAccessControl = {
        SecAccessControlCreateWithFlags(kCFAllocatorDefault,
                                        kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
                                        .userPresence,
                                        nil)!
    }()
    
    public func clearKeys(_ key: String) {
        for service in SileoService.allCases {
            let query = [
                kSecClass as String: kSecClassGenericPassword as String,
                kSecAttrAccessGroup: accessGroup,
                kSecAttrAccount as String: key,
                kSecAttrService as String: service.rawValue
            ] as [AnyHashable: String]
            SecItemDelete(query as CFDictionary)
        }
    }
    
    @discardableResult public func saveToken(key: String, data: String) -> OSStatus {
        let query = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecAttrAccessGroup: accessGroup,
            kSecAttrService as String: SileoService.token.rawValue,
            kSecValueData as String: data.data(using: .utf8) as Any,
            kSecAttrSynchronizable as String: kCFBooleanFalse!
        ] as [AnyHashable: Any]
        
        SecItemDelete(query as CFDictionary)
        let response = SecItemAdd(query as CFDictionary, nil)
        return response
    }
    
    @discardableResult public func saveSecret(key: String, data: String) -> OSStatus {
        let query = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecAttrAccessGroup: accessGroup,
            kSecAttrService as String: SileoService.secret.rawValue,
            kSecValueData as String: data.data(using: .utf8) as Any,
            kSecAttrAccessControl as String: accessControl,
            kSecAttrSynchronizable as String: kCFBooleanFalse!
        ] as [AnyHashable: Any]
        
        SecItemDelete(query as CFDictionary)
        let response = SecItemAdd(query as CFDictionary, nil)
        return response
    }
    
    public func token(key: String) -> String? {
        let query = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecAttrAccessGroup: accessGroup,
            kSecAttrService as String: SileoService.token.rawValue,
            kSecReturnData as String: kCFBooleanTrue!,
            kSecMatchLimit as String: kSecMatchLimitOne
        ] as [AnyHashable: Any]
        
        var dataRef: AnyObject?
        let status: OSStatus = SecItemCopyMatching(query as CFDictionary, &dataRef)
        guard status == noErr,
              let data = dataRef as? Data else { return nil }
        return String(decoding: data, as: UTF8.self)
    }
    
    public func secret(key: String, _ completion: @escaping (String?) -> ()) {
        let authContext = LAContext()
        authContext.evaluateAccessControl(accessControl,
                                          operation: .useItem,
                                          localizedReason: String(localizationKey: "Authenticate to complete your purchase")) { [self] (success, error) in
            guard success else { return completion(nil) }
            let query = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrAccount as String: key,
                kSecAttrAccessGroup: accessGroup,
                kSecAttrService as String: SileoService.secret.rawValue,
                kSecReturnData as String: kCFBooleanTrue!,
                kSecMatchLimit as String: kSecMatchLimitOne,
                kSecAttrAccessControl as String: accessControl,
                kSecUseAuthenticationContext as String: authContext,
                kSecUseAuthenticationUI as String: kSecUseAuthenticationUIFail
            ] as [AnyHashable: Any]
            var dataRef: AnyObject?
            let status: OSStatus = SecItemCopyMatching(query as CFDictionary, &dataRef)
            guard status == noErr,
                  let data = dataRef as? Data else { return completion(nil) }
            completion(String(decoding: data, as: UTF8.self))
        }
    }
}
