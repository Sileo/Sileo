//
//  PaymentAuthenticationBannerView.swift
//  Sileo
//
//  Created by CoolStar on 7/30/19.
//  Copyright © 2019 CoolStar. All rights reserved.
//

import Foundation

final class PaymentAuthenticationBannerView: UIView {
    private var stackView: UIStackView
    private var hairlineHeightConstraint: NSLayoutConstraint?
    private var provider: PaymentProvider
    private var viewController: UIViewController
    
    init(provider: PaymentProvider, bannerDictionary: [String: String], viewController: UIViewController) {
        self.provider = provider
        self.viewController = viewController
        
        let textLabel = SileoLabelView()
        let button = PackageButton()
        
        stackView = UIStackView(arrangedSubviews: [textLabel, button])
        
        super.init(frame: .zero)
        
        self.translatesAutoresizingMaskIntoConstraints = false
        
        self.backgroundColor = .sileoBannerColor
        
        textLabel.text = bannerDictionary["message"]
        textLabel.font = UIFont.systemFont(ofSize: 15)
        textLabel.numberOfLines = 4
        
        button.setTitle(bannerDictionary["button"]?.uppercased(), for: .normal)
        button.addTarget(self, action: #selector(PaymentAuthenticationBannerView.buttonTapped), for: .touchUpInside)
        button.setContentHuggingPriority(.required, for: .horizontal)
        button.titleLabel?.font = UIFont.systemFont(ofSize: 15, weight: .bold)
        
        stackView.translatesAutoresizingMaskIntoConstraints = false
        stackView.axis = .horizontal
        stackView.spacing = 16
        stackView.alignment = .center
        self.addSubview(stackView)
        
        stackView.topAnchor.constraint(equalTo: self.topAnchor, constant: 16).isActive = true
        stackView.bottomAnchor.constraint(equalTo: self.bottomAnchor, constant: -16).isActive = true
        stackView.leftAnchor.constraint(equalTo: self.leftAnchor, constant: 20).isActive = true
        stackView.rightAnchor.constraint(equalTo: self.rightAnchor, constant: -20).isActive = true
        
        let separatorView = UIView()
        separatorView.translatesAutoresizingMaskIntoConstraints = false
        separatorView.backgroundColor = UIColor(white: 0, alpha: 0.07)
        self.addSubview(separatorView)
        separatorView.leftAnchor.constraint(equalTo: self.leftAnchor).isActive = true
        separatorView.rightAnchor.constraint(equalTo: self.rightAnchor).isActive = true
        separatorView.bottomAnchor.constraint(equalTo: self.bottomAnchor).isActive = true
        hairlineHeightConstraint = separatorView.heightAnchor.constraint(equalToConstant: 1)
        hairlineHeightConstraint?.isActive = true
        
        weak var weakSelf = self
        NotificationCenter.default.addObserver(weakSelf as Any,
                                               selector: #selector(updateSileoColors),
                                               name: SileoThemeManager.sileoChangedThemeNotification,
                                               object: nil)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    @objc func updateSileoColors() {
        self.backgroundColor = .sileoBannerColor
    }
    
    override func didMoveToWindow() {
        super.didMoveToWindow()
        hairlineHeightConstraint?.constant = 1 / (self.window?.screen.scale ?? 1)
    }
    
    @objc func buttonTapped(_ selector: Any?) {
        PaymentAuthenticator.shared.authenticate(provider: provider, window: self.window) { error, success in
            if let error = error {
                self.viewController.present(PaymentError.alert(for: error,
                                                               title: String(localizationKey: "Provider_Auth_Fail.Title", type: .error)),
                                            animated: true, completion: nil)
            }
            if success {
                self.isHidden = true
            }
        }
    }
}
