//
//  PaymentAuthenticationBannerView.swift
//  Sileo
//
//  Created by CoolStar on 7/30/19.
//  Copyright © 2022 Sileo Team. All rights reserved.
//

import Foundation

final class PaymentAuthenticationBannerView: UIView {
    private var stackView: UIStackView
    private var hairlineHeightConstraint: NSLayoutConstraint?
    private weak var provider: PaymentProvider?
    private weak var viewController: CategoryViewController?
    
    init(provider: PaymentProvider, bannerDictionary: [String: String], viewController: CategoryViewController) {
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
    
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        self.updateSileoColors()
    }
    
    @objc func updateSileoColors() {
        self.backgroundColor = .sileoBannerColor
    }
    
    override func didMoveToWindow() {
        super.didMoveToWindow()
        hairlineHeightConstraint?.constant = 1 / (self.window?.screen.scale ?? 1)
    }
    
    @objc func buttonTapped(_ selector: Any?) {
        guard let provider = provider else { return }
        PaymentAuthenticator.shared.authenticate(provider: provider, window: self.window) { [weak self] error, success in
            guard let self = self else { return }
            if let error = error {
                self.viewController?.present(PaymentError.alert(for: error,
                                                                title: String(localizationKey: "Provider_Auth_Fail.Title", type: .error)),
                                            animated: true, completion: nil)
                return
            }
            if success {
                self.removeFromSuperview()
                self.viewController?.updateHeaderStackView()
            }
        }
    }
}
