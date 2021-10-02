//
//  PaymentProviderTableViewCell.swift
//  Sileo
//
//  Created by Skitty on 1/26/20.
//  Copyright © 2020 Sileo Team. All rights reserved.
//

import UIKit
import Evander

class PaymentProviderTableViewCell: UITableViewCell {
    private var titleLabel: UILabel = UILabel()
    private var subtitleLabel: UILabel = UILabel()
    private var iconView: PackageIconView = PackageIconView()
    private var loadingView: UIActivityIndicatorView?
    public var isAuthenticated: Bool = false
    
    override var textLabel: UILabel? {
        get {
            titleLabel
        }
        set {
            titleLabel = newValue ?? UILabel()
        }
    }
    
    override var detailTextLabel: UILabel? {
        get {
            subtitleLabel
        }
        set {
            subtitleLabel = newValue ?? UILabel()
        }
    }
    
    override var imageView: PackageIconView? {
        get {
            iconView
        }
        set {
            iconView = newValue ?? PackageIconView()
        }
    }
    
    var provider: PaymentProvider? {
        didSet {
            self.textLabel?.text = String(localizationKey: "Loading")
            self.detailTextLabel?.text = provider?.baseURL.absoluteString
            self.loadingView?.startAnimating()
            provider?.fetchInfo(fromCache: true) { _, info in
                if info == nil {
                    return
                }
                DispatchQueue.main.async {
                    let info = info as [String: Any]? ?? [:]
                    let name = info["name"] as? String
                    let description = info["description"] as? String
                    self.titleLabel.text = name
                    self.subtitleLabel.text = self.isAuthenticated ? String(localizationKey: "Payment_Provider_Signed_In") : description
                    self.loadingView?.stopAnimating()
                    self.setImage(nil)
                    let url = info["icon"] as? String ?? ""
                    if !url.isEmpty {
                        if let image = EvanderNetworking.shared.image(url, size: self.imageView?.frame.size, { [weak self] refresh, image in
                            if refresh,
                               let strong = self,
                               let image = image,
                               url == strong.provider?.info?["icon"] as? String {
                                DispatchQueue.main.async {
                                    strong.setImage(image)
                                }
                            }
                        }) {
                            self.setImage(image)
                        } else {
                            self.setImage(nil)
                        }
                    }
                    if self.isAuthenticated {
                        self.provider?.fetchUserInfo(fromCache: true) { _, userInfo in
                            DispatchQueue.main.async {
                                if let userInfo = userInfo as [String: Any]? {
                                    if let user = userInfo["user"] as? [String: String],
                                        let username = user["name"] {
                                        let string = String(localizationKey: "Payment_Provider_Signed_In_With_Name")
                                        self.subtitleLabel.text = String(format: string, username)
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        
        self.preservesSuperviewLayoutMargins = true
        self.contentView.preservesSuperviewLayoutMargins = true
        self.accessoryType = UITableViewCell.AccessoryType.disclosureIndicator

        titleLabel.font = UIFont.systemFont(ofSize: 16)

        subtitleLabel.font = UIFont.systemFont(ofSize: 12)

        iconView.contentMode = UIView.ContentMode.scaleAspectFit
        iconView.translatesAutoresizingMaskIntoConstraints = false
        iconView.isHidden = true
        iconView.widthAnchor.constraint(equalToConstant: 32).isActive = true
        iconView.heightAnchor.constraint(equalTo: self.iconView.widthAnchor).isActive = true

        loadingView = UIActivityIndicatorView(style: UIActivityIndicatorView.Style.gray)
        loadingView?.hidesWhenStopped = true

        let textStackView: UIStackView = UIStackView(arrangedSubviews: [self.titleLabel, self.subtitleLabel])
        textStackView.spacing = 2
        textStackView.axis = NSLayoutConstraint.Axis.vertical

        let stackView: UIStackView = UIStackView(arrangedSubviews: [self.loadingView ?? UIActivityIndicatorView(), self.iconView, textStackView])
        stackView.spacing = 12
        stackView.translatesAutoresizingMaskIntoConstraints = false
        stackView.alignment = UIStackView.Alignment.center
        self.contentView.addSubview(stackView)

        stackView.centerYAnchor.constraint(greaterThanOrEqualTo: self.contentView.centerYAnchor).isActive = true
        stackView.leftAnchor.constraint(equalTo: self.contentView.layoutMarginsGuide.leftAnchor).isActive = true
        stackView.rightAnchor.constraint(equalTo: self.contentView.layoutMarginsGuide.rightAnchor).isActive = true
        
        weak var weakSelf = self
        NotificationCenter.default.addObserver(weakSelf as Any,
                                               selector: #selector(updateSileoColors),
                                               name: SileoThemeManager.sileoChangedThemeNotification,
                                               object: nil)
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        isAuthenticated = false
    }

    func setImage(_ image: UIImage?) {
        iconView.isHidden = image == nil
        iconView.image = image
    }
    
    @objc func updateSileoColors() {
        titleLabel.textColor = .tintColor
        subtitleLabel.textColor = .tintColor
    }
}
