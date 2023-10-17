//
//  SettingsSwitchCell.swift
//  Sileo
//
//  Created by Amy on 16/03/2021.
//  Copyright © 2022 Sileo Team. All rights reserved.
//

import UIKit
import Evander

class SettingsSwitchTableViewCell: UITableViewCell {
    
    public var control: UISwitch = UISwitch()
    public var amyPogLabel: UILabel = UILabel()
    var viewControllerForPresentation: UIViewController?
    var fallback = false
    
    var defaultKey: String? {
        didSet {
            if let key = defaultKey { control.isOn = UserDefaults.standard.bool(forKey: key, fallback: fallback) }
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        
        self.backgroundColor = .clear
        self.selectionStyle = .none
        
        amyPogLabel.numberOfLines = 0
        amyPogLabel.adjustsFontForContentSizeCategory = true
        amyPogLabel.lineBreakMode = .byWordWrapping
        amyPogLabel.textColor = .tintColor
        
        control.onTintColor = .tintColor
        
        self.contentView.addSubview(control)
        self.contentView.addSubview(amyPogLabel)
        
        amyPogLabel.translatesAutoresizingMaskIntoConstraints = false
        control.translatesAutoresizingMaskIntoConstraints = false
        
        control.centerYAnchor.constraint(equalTo: self.centerYAnchor).isActive = true
        control.addTarget(self, action: #selector(self.didChange(sender:)), for: .valueChanged)
        
        amyPogLabel.centerYAnchor.constraint(equalTo: self.centerYAnchor).isActive = true
        amyPogLabel.leadingAnchor.constraint(equalTo: self.leadingAnchor, constant: 20).isActive = true
        control.leadingAnchor.constraint(equalTo: amyPogLabel.trailingAnchor, constant: 5).isActive = true
        control.trailingAnchor.constraint(equalTo: self.layoutMarginsGuide.trailingAnchor).isActive = true
        amyPogLabel.setContentHuggingPriority(.required, for: .vertical)
        amyPogLabel.setContentCompressionResistancePriority(.required, for: .vertical)
        
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(updateSileoColors),
                                               name: SileoThemeManager.sileoChangedThemeNotification,
                                               object: nil)
    }

    
    @objc public func didChange(sender: UISwitch!) {
        if let key = defaultKey {
            if key == "DeveloperMode" && sender.isOn {
                guard let view = viewControllerForPresentation else { return }
                let alert = UIAlertController(title: String(localizationKey: "Developer_Mode"), message: String(localizationKey: "Developer_Mode_Explain"), preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: String(localizationKey: "Cancel"), style: .cancel) { _ in
                    sender.isOn = false
                })
                alert.addAction(UIAlertAction(title: String(localizationKey: "OK"), style: .default) { _ in
                    UserDefaults.standard.setValue(sender.isOn, forKey: key); NotificationCenter.default.post(name: Notification.Name(key), object: nil)
                    let alert = UIAlertController(title: String(localizationKey: "Pog_Developer"), message: nil, preferredStyle: .alert)
                    alert.addAction(UIAlertAction(title: String(localizationKey: "OK"), style: .default))
                    view.present(alert, animated: true)
                })
                view.present(alert, animated: true)
            } else {
                UserDefaults.standard.setValue(sender.isOn, forKey: key)
                NotificationCenter.default.post(name: Notification.Name(key), object: nil)
            }
        }
    }
    
    @objc private func updateSileoColors() {
        amyPogLabel.textColor = .tintColor
        control.onTintColor = .tintColor
    }
}

class SettingsLabelTableViewCell: UITableViewCell {
    
    public var amyPogLabel: UILabel = UILabel()
    public var detailLabel: UILabel = UILabel()
    
    var viewControllerForPresentation: UIViewController?
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        
        self.backgroundColor = .clear
        self.selectionStyle = .none
        
        amyPogLabel.numberOfLines = 0
        amyPogLabel.adjustsFontForContentSizeCategory = true
        amyPogLabel.lineBreakMode = .byWordWrapping
        amyPogLabel.textColor = .tintColor
        
        detailLabel.numberOfLines = 1
        detailLabel.textColor = .gray
        
        contentView.addSubview(amyPogLabel)
        contentView.addSubview(detailLabel)
        
        amyPogLabel.translatesAutoresizingMaskIntoConstraints = false
        amyPogLabel.centerYAnchor.constraint(equalTo: contentView.centerYAnchor).isActive = true
        amyPogLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20).isActive = true
        amyPogLabel.setContentHuggingPriority(.required, for: .vertical)
        amyPogLabel.setContentCompressionResistancePriority(.required, for: .vertical)
        
        detailLabel.translatesAutoresizingMaskIntoConstraints = false
        detailLabel.centerYAnchor.constraint(equalTo: contentView.centerYAnchor).isActive = true
        detailLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20).isActive = true
        detailLabel.setContentHuggingPriority(.required, for: .vertical)
        detailLabel.setContentCompressionResistancePriority(.required, for: .vertical)
    }

    @objc private func updateSileoColors() {
        amyPogLabel.textColor = .tintColor
    }
}
