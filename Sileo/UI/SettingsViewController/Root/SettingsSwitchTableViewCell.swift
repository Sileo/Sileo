//
//  SettingsSwitchCell.swift
//  Sileo
//
//  Created by Amy on 16/03/2021.
//  Copyright © 2021 CoolStar. All rights reserved.
//

import UIKit

class SettingsSwitchTableViewCell: UITableViewCell {
    
    private var control: UISwitch = UISwitch()
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
        self.textLabel?.textColor = .tintColor
        self.addSubview(control)
        control.translatesAutoresizingMaskIntoConstraints = false
        control.onTintColor = .tintColor
        control.centerYAnchor.constraint(equalTo: self.centerYAnchor).isActive = true
        control.trailingAnchor.constraint(equalTo: self.layoutMarginsGuide.trailingAnchor).isActive = true
        control.addTarget(self, action: #selector(self.didChange(sender:)), for: .valueChanged)
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(updateSileoColors),
                                               name: SileoThemeManager.sileoChangedThemeNotification,
                                               object: nil)
    }
    
    @objc private func didChange(sender: UISwitch!) {
        if let key = defaultKey {
            UserDefaults.standard.setValue(sender.isOn, forKey: key); NotificationCenter.default.post(name: Notification.Name(key), object: nil)
            if !sender.isOn { return }
            if key == "DeveloperMode",
               let view = viewControllerForPresentation {
                let alert = UIAlertController(title: String(localizationKey: "Pog_Developer"), message: nil, preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: String(localizationKey: "OK"), style: .default))
                view.present(alert, animated: true)
            }
        }
    }
    
    @objc private func updateSileoColors() {
        textLabel?.textColor = .tintColor
        control.onTintColor = .tintColor
    }
}
