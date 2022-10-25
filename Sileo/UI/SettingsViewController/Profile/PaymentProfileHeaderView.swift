//
//  PaymentProfileHeaderView.swift
//  Sileo
//
//  Created by Skitty on 1/28/20.
//  Copyright © 2022 Sileo Team. All rights reserved.
//

import Foundation

class PaymentProfileHeaderView: UIView, SettingsHeaderViewDisplayable {
    private var loadingView: UIActivityIndicatorView = UIActivityIndicatorView(style: .gray)
    private var stackView: UIStackView = UIStackView()
    private var providerLabel: UILabel = UILabel()
    private var nameLabel: UILabel = UILabel()
    private var emailLabel: UILabel = UILabel()
    
    public var info: [String: Any]? {
        didSet {
            self.updateDisplay()
        }
    }
    public var userInfo: [String: Any]? {
        didSet {
            self.updateDisplay()
        }
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        loadingView.translatesAutoresizingMaskIntoConstraints = false
        self.addSubview(loadingView)
        
        loadingView.centerXAnchor.constraint(equalTo: self.centerXAnchor).isActive = true
        loadingView.centerYAnchor.constraint(equalTo: self.centerYAnchor, constant: -12).isActive = true
        loadingView.startAnimating()
        
        providerLabel.textColor = UIColor(white: 0, alpha: 0.25)
        providerLabel.font = UIFont.systemFont(ofSize: 13, weight: UIFont.Weight.bold)
        
        nameLabel.font = UIFont.systemFont(ofSize: 34, weight: UIFont.Weight.medium)
        nameLabel.adjustsFontSizeToFitWidth = true
        nameLabel.minimumScaleFactor = 0.65
        
        emailLabel.textColor = UIColor(white: 0, alpha: 0.3)
        emailLabel.font = UIFont.systemFont(ofSize: 26, weight: UIFont.Weight.medium)
        
        stackView = UIStackView(arrangedSubviews: [providerLabel, nameLabel, emailLabel])
        stackView.translatesAutoresizingMaskIntoConstraints = false
        stackView.isHidden = true
        stackView.spacing = 8
        stackView.axis = NSLayoutConstraint.Axis.vertical
        self.addSubview(stackView)
        
        stackView.centerYAnchor.constraint(equalTo: self.centerYAnchor, constant: -12).isActive = true
        stackView.leftAnchor.constraint(equalTo: self.leftAnchor, constant: 20).isActive = true
        stackView.rightAnchor.constraint(equalTo: self.rightAnchor, constant: -20).isActive = true
    }
    
    func headerHeight(forWidth width: CGFloat) -> CGFloat {
        166
    }

    func isLoading() -> Bool {
        userInfo == nil || info == nil
    }

    func updateDisplay() {
        if self.isLoading() {
            loadingView.startAnimating()
            stackView.isHidden = true
            return
        }
        loadingView.stopAnimating()
        stackView.isHidden = false
        let name = info?["name"] as? String
        providerLabel.attributedText = NSAttributedString(string: name?.uppercased() ?? "", attributes: [NSAttributedString.Key.kern: 0.8])
        let user: [String: String]? = userInfo?["user"] as? [String: String]
        nameLabel.text = user?["name"]
        emailLabel.text = user?["email"]
    }
}
