//
//  SettingsViewController.swift
//  Sileo
//
//  Created by Skitty on 1/26/20.
//  Copyright © 2020 CoolStar. All rights reserved.
//

import Foundation
import AUPickerCell
import Alderis

let kLocalizationCreditTitleKey = "__LocalizationCredit.Title"
let kLocalizationCreditURLKey = "__LocalizationCredit.URL"

class SettingsViewController: BaseSettingsViewController, AUPickerCellDelegate {
    private var authenticatedProviders: [PaymentProvider] = Array()
    private var unauthenticatedProviders: [PaymentProvider] = Array()
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
        
        authenticatedProviders = Array()
        unauthenticatedProviders = Array()
        self.loadProviders()
        
        self.title = "Sileo"
        
        headerView = SettingsIconHeaderView()
        
        observer = NotificationCenter.default.addObserver(forName: NSNotification.Name(rawValue: PaymentProvider.listUpdateNotificationName),
                                                          object: nil,
                                                          queue: OperationQueue.main) { _ in
            self.loadProviders()
        }
        
        weak var weakSelf = self
        NotificationCenter.default.addObserver(weakSelf as Any,
                                               selector: #selector(updateSileoColors),
                                               name: SileoThemeManager.sileoChangedThemeNotification,
                                               object: nil)
    }
    
    override func updateSileoColors() {
        super.updateSileoColors()
        tableView.reloadData()
    }
    
    func showTranslationCreditSection() -> Bool {
        !(kLocalizationCreditTitleKey == String(localizationKey: kLocalizationCreditTitleKey))
    }
    
    func hasTranslationCreditLink() -> Bool {
        !(kLocalizationCreditTitleKey == String(localizationKey: kLocalizationCreditURLKey))
    }
    
    func loadProviders() {
        PaymentManager.shared.getAllPaymentProviders { providers in
            self.hasLoadedOnce = true
            
            self.authenticatedProviders = Array()
            self.unauthenticatedProviders = Array()

            for provider in providers {
                if provider.isAuthenticated {
                    self.authenticatedProviders.append(provider)
                } else {
                    self.unauthenticatedProviders.append(provider)
                }
            }
            
            DispatchQueue.main.async {
                self.tableView.reloadSections(IndexSet(integersIn: 0...0), with: UITableView.RowAnimation.automatic)
            }
        }
    }
}

extension SettingsViewController { // UITableViewDataSource
    override func numberOfSections(in tableView: UITableView) -> Int {
        3 + (showTranslationCreditSection() ? 1 : 0)
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch section {
        case 0: // Payment Providers section
            return authenticatedProviders.count + unauthenticatedProviders.count + (hasLoadedOnce ? 0 : 1) + 1
        case 1: // Translation Credit Section OR Settings section
            if showTranslationCreditSection() {
                return 1
            }
            return 3
        case 2: // Settings section OR About section
            if showTranslationCreditSection() {
                return 3
            }
            return 1
        case 3: // About section
            return 1
        default:
            return 0
        }
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        switch indexPath.section {
        case 0: // Payment Providers section
            if indexPath.row < authenticatedProviders.count {
                // Authenticated Provider
                let style = UITableViewCell.CellStyle.subtitle
                let id = "PaymentProviderCellIdentifier"
                let cellClass = PaymentProviderTableViewCell.self
                let cell = self.reusableCell(withStyle: style, reuseIdentifier: id, cellClass: cellClass) as? PaymentProviderTableViewCell
                cell?.isAuthenticated = true
                cell?.provider = authenticatedProviders[indexPath.row]
                return cell ?? UITableViewCell()
            } else if indexPath.row - authenticatedProviders.count < unauthenticatedProviders.count {
                // Unauthenticated Provider
                let style = UITableViewCell.CellStyle.subtitle
                let id = "PaymentProviderCellIdentifier"
                let cellClass = PaymentProviderTableViewCell.self
                let cell = self.reusableCell(withStyle: style, reuseIdentifier: id, cellClass: cellClass) as? PaymentProviderTableViewCell
                cell?.provider = unauthenticatedProviders[indexPath.row - authenticatedProviders.count]
                return cell ?? UITableViewCell()
            } else if !hasLoadedOnce && (indexPath.row - authenticatedProviders.count - unauthenticatedProviders.count) == 0 {
                let style = UITableViewCell.CellStyle.subtitle
                let id = "LoadingCellIdentifier"
                let cellClass = SettingsLoadingTableViewCell.self
                return self.reusableCell(withStyle: style, reuseIdentifier: id, cellClass: cellClass)
            }
            let cell: UITableViewCell? = self.reusableCell(withStyle: UITableViewCell.CellStyle.default, reuseIdentifier: "CydiaCellIdentifier")
            cell?.textLabel?.text = String(localizationKey: "Cydia_Sign_In")
            cell?.accessoryType = UITableViewCell.AccessoryType.disclosureIndicator
            return cell ?? UITableViewCell()
        case 1: // Translation Credit Section OR Settings section
            if self.showTranslationCreditSection() {
                let style = UITableViewCell.CellStyle.default
                let cell: UITableViewCell = self.reusableCell(withStyle: style, reuseIdentifier: "TranslationCellIdentifier")
                cell.textLabel?.text = String(localizationKey: kLocalizationCreditTitleKey)
                let none = UITableViewCell.AccessoryType.none
                cell.accessoryType = self.hasTranslationCreditLink() ? UITableViewCell.AccessoryType.disclosureIndicator : none
                cell.selectionStyle = self.hasTranslationCreditLink() ? UITableViewCell.SelectionStyle.default : UITableViewCell.SelectionStyle.none
                return cell
            } else {
                switch indexPath.row {
                case 0:
                    let cell = AUPickerCell(type: .default, reuseIdentifier: "SettingsCellIdentifier")
                    cell.delegate = self
                    cell.values = SileoThemeManager.shared.themeList.map({ $0.name })
                    cell.selectedRow = cell.values.firstIndex(of: SileoThemeManager.shared.currentTheme.name) ?? 0
                    cell.leftLabel.text = String(localizationKey: "Theme")
                    cell.backgroundColor = nil
                    cell.leftLabel.textColor = .tintColor
                    cell.rightLabel.textColor = .tintColor
                    return cell
                case 1:
                    let cell = SettingsColorTableViewCell()
                    cell.textLabel?.text = String(localizationKey: "Tint_Color")
                    return cell
                case 2:
                    let cell = self.reusableCell(withStyle: .default, reuseIdentifier: "ResetTintCellIdentifier")
                    cell.textLabel?.text = String(localizationKey: "Reset_Tint_Color")
                    return cell
                default:
                    return UITableViewCell()
                }
            }
        case 2: // Settings section OR About section
            if self.showTranslationCreditSection() {
                switch indexPath.row {
                case 0:
                    let cell = AUPickerCell(type: .default, reuseIdentifier: "SettingsCellIdentifier")
                    cell.delegate = self
                    cell.values = SileoThemeManager.shared.themeList.map({ $0.name })
                    cell.selectedRow = cell.values.firstIndex(of: SileoThemeManager.shared.currentTheme.name) ?? 0
                    cell.leftLabel.text = String(localizationKey: "Theme")
                    cell.backgroundColor = nil
                    cell.leftLabel.textColor = .tintColor
                    cell.rightLabel.textColor = .tintColor
                    return cell
                case 1:
                    let cell = SettingsColorTableViewCell()
                    cell.textLabel?.text = String(localizationKey: "Tint_Color")
                    return cell
                case 2:
                    let cell = self.reusableCell(withStyle: .default, reuseIdentifier: "ResetTintCellIdentifier")
                    cell.textLabel?.text = String(localizationKey: "Reset_Tint_Color")
                    return cell
                default:
                    return UITableViewCell()
                }
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
        if let cell = tableView.cellForRow(at: indexPath) as? AUPickerCell {
            cell.selectedInTableView(tableView)
        }
        
        switch indexPath.section {
        case 0: // Payment Providers section
            if indexPath.row < authenticatedProviders.count {
                // Authenticated Provider
                let provider: PaymentProvider = authenticatedProviders[indexPath.row]
                let profileViewController: PaymentProfileViewController = PaymentProfileViewController(provider: provider)
                self.navigationController?.pushViewController(profileViewController, animated: true)
            } else if indexPath.row - authenticatedProviders.count < unauthenticatedProviders.count {
                // Unauthenticated Provider
                let provider: PaymentProvider = unauthenticatedProviders[indexPath.row - authenticatedProviders.count]
                PaymentAuthenticator.shared.authenticate(provider: provider, window: self.view.window) { error, _ in
                    if error != nil {
                        let title: String = String(localizationKey: "Provider_Auth_Fail.Title", type: .error)
                        self.present(PaymentError.alert(for: error, title: title), animated: true)
                    }
                }
            } else if hasLoadedOnce || (indexPath.row - authenticatedProviders.count - unauthenticatedProviders.count) > 0 {
                tableView.deselectRow(at: indexPath, animated: true)
                let nibName = "CydiaAccountViewController"
                let cydiaAccountViewController: CydiaAccountViewController = CydiaAccountViewController(nibName: nibName, bundle: nil)
                let navController: UINavigationController = UINavigationController(rootViewController: cydiaAccountViewController)
                self.present(navController, animated: true)
            }
        case 1: // Translation Credit Section OR Settings section
            if self.showTranslationCreditSection() {
                guard let url = URL(string: String(localizationKey: kLocalizationCreditURLKey)) else {
                    return
                }
                UIApplication.shared.open(url, options: [:])
            } else if indexPath.row == 1 { // Tint color selector
                let colorPickerViewController = ColorPickerViewController()
                colorPickerViewController.delegate = self
                colorPickerViewController.configuration = ColorPickerConfiguration(color: .tintColor)
                if UIDevice.current.userInterfaceIdiom == .pad {
                    if #available(iOS 13.0, *) {
                        colorPickerViewController.modalPresentationStyle = .popover
                        colorPickerViewController.popoverPresentationController?.sourceView = self.navigationController?.view
                    } else {
                        colorPickerViewController.modalPresentationStyle = .fullScreen
                    }
                }
                
                self.navigationController?.present(colorPickerViewController, animated: true)
            } else if indexPath.row == 2 { // Tint color reset
                SileoThemeManager.shared.resetTintColor()
            }
        case 2: // Settings section OR About section
            if self.showTranslationCreditSection() {
                if indexPath.row == 1 { // Tint color selector
                    let colorPickerViewController = ColorPickerViewController()
                    colorPickerViewController.delegate = self
                    colorPickerViewController.configuration = ColorPickerConfiguration(color: .tintColor)
                    if UIDevice.current.userInterfaceIdiom == .pad {
                        if #available(iOS 13.0, *) {
                            colorPickerViewController.modalPresentationStyle = .popover
                            colorPickerViewController.popoverPresentationController?.sourceView = self.navigationController?.view
                        } else {
                            colorPickerViewController.modalPresentationStyle = .fullScreen
                        }
                    }
                    self.navigationController?.present(colorPickerViewController, animated: true)
                    
                } else if indexPath.row == 2 { // Tint color reset
                    SileoThemeManager.shared.resetTintColor()
                }
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
        case 1: // Translation Credit Section OR Settings section
            if self.showTranslationCreditSection() {
                    return String(localizationKey: "Settings_Translations_Heading")
            } else {
                return String(localizationKey: "Settings")
            }
        case 2: // Settings section OR About section
            if self.showTranslationCreditSection() {
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
        if let cell = tableView.cellForRow(at: indexPath) as? AUPickerCell {
            return cell.height
        }
        
        let auth = authenticatedProviders.count
        let unauth = unauthenticatedProviders.count
        if indexPath.section == 0 && (indexPath.row < auth || indexPath.row - auth < unauth) {
            return 54
        }
        return super.tableView(tableView, heightForRowAt: indexPath)
    }
    
    func auPickerCell(_ cell: AUPickerCell, didPick row: Int, value: Any) {
        SileoThemeManager.shared.activate(theme: SileoThemeManager.shared.themeList[row])
    }
}

extension SettingsViewController: ColorPickerDelegate {
    func colorPicker(_ colorPicker: ColorPickerViewController, didSelect color: UIColor) {
        SileoThemeManager.shared.setTintColor(color)
    }
}
