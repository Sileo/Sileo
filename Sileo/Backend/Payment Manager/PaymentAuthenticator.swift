//
//  PaymentAuthenticator.swift
//  Sileo
//
//  Created by Skitty on 6/28/20.
//  Copyright © 2022 Sileo Team. All rights reserved.
//

import Foundation
import AuthenticationServices
import SafariServices

class PaymentAuthenticator: NSObject, ASWebAuthenticationPresentationContextProviding {
    public static let shared = PaymentAuthenticator()
    private var currentAuthenticationSession: NSObject?
    private var lastWindow: UIWindow?
    
    func authenticate(provider: PaymentProvider, window: UIWindow?, completion: ((PaymentError?, Bool) -> Void)?) {
        let callback: (URL?, Error?) -> Void = { url, error in
            if #available(iOS 12, macCatalyst 12, *) {
                if let error = error {
                    if let error = error as? ASWebAuthenticationSessionError,
                        error.code == ASWebAuthenticationSessionError.canceledLogin {
                        completion?(nil, false)
                        return
                    }
                    completion?(PaymentError(error: error), false)
                    return
                }
            } else {
                #if !targetEnvironment(macCatalyst)
                if let error = error {
                    if let error = error as? SFAuthenticationError,
                       error.code == SFAuthenticationError.canceledLogin {
                        completion?(nil, false)
                        return
                    }
                    completion?(PaymentError(error: error), false)
                    return
                }
                #endif
            }
            
            guard let url = url,
                url.host == "authentication_success" else {
                    completion?(PaymentError.invalidResponse, false)
                    return
            }
            
            let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
            var token: String?
            var secret: String?
            
            for item in components?.queryItems ?? [] {
                if item.name == "token" && item.value != nil {
                    token = item.value
                } else if item.name == "payment_secret" && item.value != nil {
                    secret = item.value
                }
                if token != nil && secret != nil {
                    break
                }
            }
            
            if token == nil || secret == nil {
                completion?(PaymentError.invalidResponse, false)
                return
            }
            
            provider.authenticate(withToken: token!, paymentSecret: secret!)
            completion?(nil, false)
        }
        
        if #available(iOS 12, macCatalyst 12, *) {
            let currentSession = ASWebAuthenticationSession(url: provider.authenticationURL, callbackURLScheme: "sileo", completionHandler: callback)
            if #available(iOS 13, *) {
                currentSession.presentationContextProvider = self
                
            }
            currentSession.start()
            currentAuthenticationSession = currentSession
        } else {
            let currentSession = SFAuthenticationSession(url: provider.authenticationURL, callbackURLScheme: "sileo", completionHandler: callback)
            currentSession.start()
            currentAuthenticationSession = currentSession
        }
    }
    
    func handlePayment(actionURL url: URL, provider: PaymentProvider, window: UIWindow?, completion: ((PaymentError?, Bool) -> Void)?) {
        let callback: (URL?, Error?) -> Void = { url, error in
            if #available(iOS 12, macCatalyst 12, *) {
                if let error = error {
                    if let error = error as? ASWebAuthenticationSessionError,
                       error.code == ASWebAuthenticationSessionError.canceledLogin {
                        completion?(nil, false)
                        return
                    }
                    completion?(PaymentError(error: error), false)
                    return
                }
            } else {
                #if !targetEnvironment(macCatalyst)
                if let error = error {
                    if let error = error as? SFAuthenticationError,
                       error.code == SFAuthenticationError.canceledLogin {
                        completion?(nil, false)
                        return
                    }
                    completion?(PaymentError(error: error), false)
                    return
                }
                #endif
            }
            guard let url = url,
                url.host == "payment_completed" else {
                    completion?(PaymentError.invalidResponse, false)
                    return
            }
            
            completion?(nil, false)
        }
        if #available(iOS 12, macCatalyst 12, *) {
            let currentSession = ASWebAuthenticationSession(url: url, callbackURLScheme: "sileo", completionHandler: callback)
            if #available(iOS 13, *) {
                currentSession.presentationContextProvider = self
            }
            currentSession.start()
            currentAuthenticationSession = currentSession
        } else {
            let currentSession = SFAuthenticationSession(url: url, callbackURLScheme: "sileo", completionHandler: callback)
            currentSession.start()
            currentAuthenticationSession = currentSession
        }
        
    }
    
    @available(iOS 12, macCatalyst 12, *)
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        UIWindow.presentable ?? ASPresentationAnchor()
    }
}

extension UIWindow {
    
    public static var presentable: UIWindow? {
        if #available(iOS 13, *) {
            return UIApplication
                .shared
                .connectedScenes
                .filter { $0.activationState == .foregroundActive }
                .flatMap { ($0 as? UIWindowScene)?.windows ?? [] }
                .first
        } else {
            return UIApplication.shared.keyWindow
        }
    }
    
}
