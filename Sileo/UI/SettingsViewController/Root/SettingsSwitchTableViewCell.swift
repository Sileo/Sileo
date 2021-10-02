//
//  SettingsSwitchCell.swift
//  Sileo
//
//  Created by Amy on 16/03/2021.
//  Copyright © 2021 Sileo Team. All rights reserved.
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
            if let key = defaultKey { control.isOn = UserDefaults.standard.optionalBool(key, fallback: fallback) }
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        
        self.backgroundColor = .clear
        self.selectionStyle = .none
        amyPogLabel.textColor = .tintColor
        control.onTintColor = .tintColor
        amyPogLabel.adjustsFontSizeToFitWidth = true
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
        amyPogLabel.setContentHuggingPriority(UILayoutPriority(251), for: .horizontal)
        amyPogLabel.setContentHuggingPriority(UILayoutPriority(251), for: .vertical)
        amyPogLabel.setContentCompressionResistancePriority(UILayoutPriority(749), for: .horizontal)

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
