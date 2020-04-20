//
//  SettingsViewController.swift
//  Sileo
//
//  Created by Skitty on 1/26/20.
//  Copyright © 2020 CoolStar. All rights reserved.
//

import Foundation

let kLocalizationCreditTitleKey = "__LocalizationCredit.Title"
let kLocalizationCreditURLKey = "__LocalizationCredit.URL"

class SettingsViewController: BaseSettingsViewController {
    private var hasLoadedOnce: Bool = false
    private var observer: Any?
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }
    
    override init(style: UITableView.Style) {
        super.init(style: style)
    }
    
    deinit {
        guard let obs = observer else { return }
        NotificationCenter.default.removeObserver(obs)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.loadProviders()
        
        self.title = "Sileo"
        
        headerView = SettingsIconHeaderView()
    }
    
    func showTranslationCreditSection() -> Bool {
        !(kLocalizationCreditTitleKey == String(localizationKey: kLocalizationCreditTitleKey))
    }
    
    func showSettingsSection() -> Bool {
        if #available(iOS 13, *) {
            return false
        } else {
            return true
        }
    }
    
    func hasTranslationCreditLink() -> Bool {
        !(kLocalizationCreditTitleKey == String(localizationKey: kLocalizationCreditURLKey))
    }
    
    @objc func darkModeChanged(_ sender: Any) {
        UIColor.isDarkModeEnabled = !UIColor.isDarkModeEnabled
        UserDefaults.standard.set(UIColor.isDarkModeEnabled, forKey: "darkMode")
        UIView.animate(withDuration: 0.25) {
            NotificationCenter.default.post(name: UIColor.sileoDarkModeNotification, object: nil)
        }
    }
    
    func loadProviders() {
    }
}

extension SettingsViewController { // UITableViewDataSource
    override func numberOfSections(in tableView: UITableView) -> Int {
        2 + (self.showTranslationCreditSection() ? 1 : 0) + (self.showSettingsSection() ? 1 : 0)
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch section {
        case 0: // Payment Providers section
            return 1
        case 1...3:
            // 1: Translation Credit Section OR Settings section OR About section
            // 2: Settings section OR About section
            // 3: About section
            return 1
        default:
            return 0
        }
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        switch indexPath.section {
        case 0: // Payment Providers section
            let cell: UITableViewCell? = self.reusableCell(withStyle: UITableViewCell.CellStyle.default, reuseIdentifier: "CydiaCellIdentifier")
            cell?.textLabel?.text = String(localizationKey: "Cydia_Sign_In")
            cell?.accessoryType = UITableViewCell.AccessoryType.disclosureIndicator
            return cell ?? UITableViewCell()
        case 1: // Translation Credit Section OR Settings section OR About section
            if self.showTranslationCreditSection() {
                let style = UITableViewCell.CellStyle.default
                let cell: UITableViewCell = self.reusableCell(withStyle: style, reuseIdentifier: "TranslationCellIdentifier")
                cell.textLabel?.text = String(localizationKey: kLocalizationCreditTitleKey)
                let none = UITableViewCell.AccessoryType.none
                cell.accessoryType = self.hasTranslationCreditLink() ? UITableViewCell.AccessoryType.disclosureIndicator : none
                cell.selectionStyle = self.hasTranslationCreditLink() ? UITableViewCell.SelectionStyle.default : UITableViewCell.SelectionStyle.none
                return cell
            } else if self.showSettingsSection() {
                let cell: UITableViewCell = self.reusableCell(withStyle: UITableViewCell.CellStyle.default, reuseIdentifier: "SettingsCellIdentifier")
                cell.textLabel?.textColor = UIColor.white
                cell.textLabel?.text = String(localizationKey: "Dark_Mode_Toggle")
                let darkModeSwitch: UISwitch = UISwitch()
                cell.accessoryView = darkModeSwitch
                cell.selectionStyle = UITableViewCell.SelectionStyle.none
                darkModeSwitch.isOn = UIColor.isDarkModeEnabled
                darkModeSwitch.addTarget(self, action: #selector(SettingsViewController.darkModeChanged(_:)), for: UIControl.Event.valueChanged)
                return cell
            } else { // About section
                let cell: UITableViewCell = self.reusableCell(withStyle: UITableViewCell.CellStyle.default, reuseIdentifier: "LicenseCellIdentifier")
                cell.textLabel?.text = String(localizationKey: "Licenses_Page_Title")
                cell.accessoryType = UITableViewCell.AccessoryType.disclosureIndicator
                return cell
            }
        case 2: // Settings section OR About section
            if self.showSettingsSection() && self.showTranslationCreditSection() {
                let cell: UITableViewCell = self.reusableCell(withStyle: UITableViewCell.CellStyle.default, reuseIdentifier: "SettingsCellIdentifier")
                cell.textLabel?.textColor = UIColor.white
                cell.textLabel?.text = String(localizationKey: "Dark_Mode_Toggle")
                let darkModeSwitch: UISwitch = UISwitch()
                cell.accessoryView = darkModeSwitch
                cell.selectionStyle = UITableViewCell.SelectionStyle.none
                darkModeSwitch.isOn = UIColor.isDarkModeEnabled
                darkModeSwitch.addTarget(self, action: #selector(SettingsViewController.darkModeChanged(_:)), for: UIControl.Event.valueChanged)
                return cell
            } else {
                let cell: UITableViewCell = self.reusableCell(withStyle: UITableViewCell.CellStyle.default, reuseIdentifier: "LicenseCellIdentifier")
                cell.textLabel?.text = String(localizationKey: "Licenses_Page_Title")
                cell.accessoryType = UITableViewCell.AccessoryType.disclosureIndicator
                return cell
            }
        case 3: // About section
            let cell: UITableViewCell = self.reusableCell(withStyle: UITableViewCell.CellStyle.default, reuseIdentifier: "LicenseCellIdentifier")
            cell.textLabel?.text = String(localizationKey: "Licenses_Page_Title")
            cell.accessoryType = UITableViewCell.AccessoryType.disclosureIndicator
            return cell
        default:
            return UITableViewCell()
        }
    }
        
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        switch indexPath.section {
        case 0: // Payment Providers section
            tableView.deselectRow(at: indexPath, animated: true)
            let nibName = "CydiaAccountViewController"
            let cydiaAccountViewController: CydiaAccountViewController = CydiaAccountViewController(nibName: nibName, bundle: nil)
            let navController: UINavigationController = UINavigationController(rootViewController: cydiaAccountViewController)
            self.present(navController, animated: true)
        case 1: // Translation Credit Section OR Settings section OR About section
            if self.showTranslationCreditSection() {
                guard let url = URL(string: String(localizationKey: kLocalizationCreditURLKey)) else {
                    return
                }
                UIApplication.shared.open(url, options: [:])
            } else if self.showSettingsSection() {
                break
            } else { // About section
                let licensesViewController: LicensesTableViewController = LicensesTableViewController()
                self.navigationController?.pushViewController(licensesViewController, animated: true)
            }
        case 2: // Settings section OR About section
            if self.showSettingsSection() && self.showTranslationCreditSection() {
                break
            } else {
                let licensesViewController: LicensesTableViewController = LicensesTableViewController()
                self.navigationController?.pushViewController(licensesViewController, animated: true)
            }
        case 3: // About section
            let licensesViewController: LicensesTableViewController = LicensesTableViewController()
            self.navigationController?.pushViewController(licensesViewController, animated: true)
        default:
            break
        }
        tableView.deselectRow(at: indexPath, animated: true)
    }
    
    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        switch section {
        case 0: // Payment Providers section
                return String(localizationKey: "Settings_Payment_Provider_Heading")
        case 1: // Translation Credit Section OR Settings section OR About section
            if self.showTranslationCreditSection() {
                    return String(localizationKey: "Settings_Translations_Heading")
            } else if self.showSettingsSection() {
                return String(localizationKey: "Settings")
            } else { // About section
                return String(localizationKey: "About")
            }
        case 2: // Settings section OR About section
            if self.showSettingsSection() && self.showTranslationCreditSection() {
                return String(localizationKey: "Settings")
            } else {
                return String(localizationKey: "About")
            }
        case 3: // About section
            return String(localizationKey: "About")
        default:
            return nil
        }
    }
    
    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        super.tableView(tableView, heightForRowAt: indexPath)
    }
}
