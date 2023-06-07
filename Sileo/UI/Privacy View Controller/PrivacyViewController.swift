//
//  PrivacyViewController.swift
//  Sileo
//
//  Created by Amy While on 07/06/2023.
//  Copyright © 2023 Sileo Team. All rights reserved.
//

import Foundation
import Onboarding

var canisterPrivacyPolicy = URL(string: "https://canister.me/privacy")!

public class PrivacyViewController {

    public static func viewController(privacyLink: URL) -> UIViewController {
        canisterPrivacyPolicy = privacyLink
        let onboardingVC: OnboardingViewController
        let title = String(localizationKey: "Download_Analytics")
        let description = String(localizationKey: "Provided_Canister")
        if #available(iOS 13, *) {
            onboardingVC = OnboardingViewController(title: title, description: description, symbolName: "person.fill")
        } else {
            onboardingVC = OnboardingViewController(title: title, description: description, image: UIImage(named: "User"))
        }
        
        onboardingVC.addBulletin(.init(title: String(localizationKey: "Why"), description: String(localizationKey: "Data_Collected"), image: UIImage(named: "Chevron")!))
        onboardingVC.addBulletin(.init(title: String(localizationKey: "Whats_Collected"), description: String(localizationKey: "Non_Identifying"), image: UIImage(named: "Chevron")!))
        onboardingVC.addBulletin(.init(title: String(localizationKey: "Settings"), description: String(localizationKey: "Change_Later"), image: UIImage(named: "Chevron")!))
        
        let privacyButton = OnboardingButton(type: .clear(textColor: .tintColor), title: String(localizationKey: "Privacy_Policy"))
        let deny = OnboardingButton(type: .clear(textColor: .tintColor), title: String(localizationKey: "Deny"))
        let accept = OnboardingButton(type: .filled(color: .tintColor), title: String(localizationKey: "Accept"))
        
       
        privacyButton.addTarget(onboardingVC, action: #selector(OnboardingViewController.privacyPolicySel), for: .touchUpInside)
        deny.addTarget(onboardingVC, action: #selector(OnboardingViewController.denySel), for: .touchUpInside)
        accept.addTarget(onboardingVC, action: #selector(OnboardingViewController.acceptSel), for: .touchUpInside)
        
        onboardingVC.addButton(privacyButton)
        onboardingVC.addButton(deny)
        onboardingVC.addButton(accept)
        
        return onboardingVC
    }

}

extension OnboardingViewController {
    
    @objc func privacyPolicySel() {
        UIApplication.shared.open(canisterPrivacyPolicy)
    }
    
    
    @objc func denySel() {
        UserDefaults.standard.setValue(false, forKey: "CanisterIngest")
        self.dismiss(animated: true)
    }
    
    @objc func acceptSel() {
        UserDefaults.standard.setValue(true, forKey: "CanisterIngest")
        self.dismiss(animated: true)
    }
    
    
}
