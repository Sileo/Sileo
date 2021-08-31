//
//  SettingsViewController.swift
//  Sileo
//
//  Created by Skitty on 1/26/20.
//  Copyright © 2020 Sileo Team. All rights reserved.
//

import Foundation
import Alderis
import UIKit

class SettingsViewController: BaseSettingsViewController, ThemeSelected {
    private var authenticatedProviders: [PaymentProvider] = Array()
    private var unauthenticatedProviders: [PaymentProvider] = Array()
    private var hasLoadedOnce: Bool = false
    private var observer: Any?
    public var themeExpanded = false
    
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
        4
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch section {
        case 0: // Payment Providers section
            return authenticatedProviders.count + unauthenticatedProviders.count + (hasLoadedOnce ? 0 : 1)
        case 1: // Themes
            return 4
        case 2:
            return 10
        case 3: // About section
            return 4
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
            return UITableViewCell()
        case 1: // Translation Credit Section OR Settings section
            switch indexPath.row {
            case 0:
                let cell = ThemePickerCell(style: .default, reuseIdentifier: "SettingsCellIdentifier")
                cell.values = SileoThemeManager.shared.themeList.map({ $0.name })
                cell.pickerView.selectRow(cell.values.firstIndex(of: SileoThemeManager.shared.currentTheme.name) ?? 0, inComponent: 0, animated: false)
                cell.callback = self
                cell.title.text = String(localizationKey: "Theme")
                cell.subtitle.text = cell.values[cell.pickerView.selectedRow(inComponent: 0)]
                cell.backgroundColor = .clear
                cell.title.textColor = .tintColor
                cell.subtitle.textColor = .tintColor
                cell.pickerView.textColor = .sileoLabel
                return cell
            case 1:
                let cell = SettingsColorTableViewCell()
                cell.textLabel?.text = String(localizationKey: "Tint_Color")
                return cell
            case 2:
                let cell = self.reusableCell(withStyle: .default, reuseIdentifier: "ResetTintCellIdentifier")
                cell.textLabel?.text = String(localizationKey: "Reset_Tint_Color")
                return cell
            case 3:
                let cell = self.reusableCell(withStyle: .default, reuseIdentifier: "AltIconCell")
                cell.textLabel?.text = String(localizationKey: "Alternate_Icon_Title")
                cell.accessoryType = .disclosureIndicator
                return cell
            default:
                fatalError("You done goofed")
            }
        case 2:
            let cell = SettingsSwitchTableViewCell()
            switch indexPath.row {
            case 0:
                cell.amyPogLabel.text = String(localizationKey: "Swipe_Actions")
                cell.fallback = true
                cell.defaultKey = "SwipeActions"
            case 1:
                cell.amyPogLabel.text = String(localizationKey: "Show_Provisional")
                cell.fallback = true
                cell.defaultKey = "ShowProvisional"
            case 2:
                cell.amyPogLabel.text = String(localizationKey: "iCloud_Profile")
                cell.fallback = true
                cell.defaultKey = "iCloudProfile"
            case 3:
                cell.amyPogLabel.text = String(localizationKey: "Show_Ignored_Updates")
                cell.fallback = true
                cell.defaultKey = "ShowIgnoredUpdates"
            case 4:
                cell.amyPogLabel.text = String(localizationKey: "Auto_Refresh_Sources")
                cell.fallback = true
                cell.defaultKey = "AutoRefreshSources"
            case 5:
                cell.amyPogLabel.text = String(localizationKey: "Auto_Complete_Queue")
                cell.defaultKey = "AutoComplete"
            case 6:
                cell.amyPogLabel.text = String(localizationKey: "Auto_Show_Queue")
                cell.fallback = true
                cell.defaultKey = "UpgradeAllAutoQueue"
            case 7:
                cell.amyPogLabel.text = String(localizationKey: "Always_Show_Install_Log")
                cell.defaultKey = "AlwaysShowLog"
            case 8:
                cell.amyPogLabel.text = String(localizationKey: "Auto_Confirm_Upgrade_All_Shortcut")
                cell.defaultKey = "AutoConfirmUpgradeAllShortcut"
            case 9:
                cell.amyPogLabel.text = String(localizationKey: "Developer_Mode")
                cell.fallback = false
                cell.defaultKey = "DeveloperMode"
                cell.viewControllerForPresentation = self
            default:
                fatalError("You done goofed")
            }
            return cell
        case 3: // About section
            switch indexPath.row {
            case 0:
                let cell = self.reusableCell(withStyle: .value1, reuseIdentifier: "CacheSizeIdenitifer")
                cell.textLabel?.text = String(localizationKey: "Cache_Size")
                cell.detailTextLabel?.text = FileManager.default.sizeString(AmyNetworkResolver.shared.cacheDirectory)
                return cell
            case 1:
                let cell: UITableViewCell = self.reusableCell(withStyle: UITableViewCell.CellStyle.default, reuseIdentifier: "LicenseCellIdentifier")
                cell.textLabel?.text = String(localizationKey: "Sileo_Team")
                cell.accessoryType = UITableViewCell.AccessoryType.disclosureIndicator
                return cell
            case 2:
                let cell: UITableViewCell = self.reusableCell(withStyle: UITableViewCell.CellStyle.default, reuseIdentifier: "LicenseCellIdentifier")
                cell.textLabel?.text = String(localizationKey: "Licenses_Page_Title")
                cell.accessoryType = UITableViewCell.AccessoryType.disclosureIndicator
                return cell
            case 3:
                let cell: UITableViewCell = self.reusableCell(withStyle: UITableViewCell.CellStyle.default, reuseIdentifier: "LicenseCellIdentifier")
                cell.textLabel?.text = String(localizationKey: "Language")
                cell.accessoryType = UITableViewCell.AccessoryType.disclosureIndicator
                return cell
            default:
                fatalError("You done goofed")
            }
            
        default:
            return UITableViewCell()
        }
    }
        
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if indexPath.row == 0 && indexPath.section == 1 {
            themeExpanded = !themeExpanded
            tableView.beginUpdates()
            tableView.endUpdates()
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
            }
        case 1:
            if indexPath.row == 1 { // Tint color selector
                self.presentAlderis()
            } else if indexPath.row == 2 { // Tint color reset
                SileoThemeManager.shared.resetTintColor()
            } else if indexPath.row == 3 {
                #if targetEnvironment(macCatalyst)
                let errorVC = UIAlertController(title: "Not Supported", message: "Alternate Icons are currently not supported in macOS", preferredStyle: .alert)
                errorVC.addAction(UIAlertAction(title: "Ok", style: .cancel, handler: { _ in errorVC.dismiss(animated: true) }))
                self.present(errorVC, animated: true)
                #else
                let altVC = AltIconTableViewController()
                self.navigationController?.pushViewController(altVC, animated: true)
                #endif
            }
        case 3: // About section
            switch indexPath.row {
            case 0:
                self.cacheClear()
            case 1:
                let teamViewController: SileoTeamViewController = SileoTeamViewController()
                self.navigationController?.pushViewController(teamViewController, animated: true)
            case 2:
                let licensesViewController: LicensesTableViewController = LicensesTableViewController()
                self.navigationController?.pushViewController(licensesViewController, animated: true)
            case 3:
                let languageSelection = LanguageSelectionViewController(style: .grouped)
                self.navigationController?.pushViewController(languageSelection, animated: true)
            default: break
            }
        default:
            break
        }
        tableView.deselectRow(at: indexPath, animated: true)
    }
    
    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        switch section {
        case 0: // Payment Providers section
            return String(localizationKey: "Settings_Payment_Provider_Heading")
        case 1:
            return String(localizationKey: "Theme_Settings")
        case 2: // Translation Credit Section OR Settings section
            return String(localizationKey: "Settings")
        case 3: // About section
            return String(localizationKey: "About")
        default:
            return nil
        }
    }
    
    private func cacheClear() {
        let alert = UIAlertController(title: String(localizationKey: "Clear_Cache"),
                                      message: String(format: String(localizationKey: "Clear_Cache_Message"), FileManager.default.sizeString(AmyNetworkResolver.shared.cacheDirectory)),
                                      preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: String(localizationKey: "OK"), style: .destructive) { _ in
            AmyNetworkResolver.shared.clearCache()
            self.tableView.reloadData()
        })
        alert.addAction(UIAlertAction(title: String(localizationKey: "Cancel"), style: .cancel))
        self.present(alert, animated: true)
    }
    
    private func presentAlderis() {
        if #available(iOS 14, *) {
            let colorPickerViewController = UIColorPickerViewController()
            colorPickerViewController.delegate = self
            colorPickerViewController.supportsAlpha = false
            colorPickerViewController.selectedColor = .tintColor
            self.present(colorPickerViewController, animated: true)
        } else {
            let colorPickerViewController = ColorPickerViewController()
            colorPickerViewController.delegate = self
            colorPickerViewController.configuration = ColorPickerConfiguration(color: .tintColor)
            if UIDevice.current.userInterfaceIdiom == .pad {
                if #available(iOS 13, *) {
                    colorPickerViewController.popoverPresentationController?.sourceView = self.navigationController?.view
                }
            }
            colorPickerViewController.modalPresentationStyle = .overFullScreen
            self.parent?.present(colorPickerViewController, animated: true, completion: nil)
        }
        
    }
    
    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        if indexPath.row == 0 && indexPath.section == 1 {
            return !themeExpanded ? 44 : 160
        }
        
        let auth = authenticatedProviders.count
        let unauth = unauthenticatedProviders.count
        if indexPath.section == 0 && (indexPath.row < auth || indexPath.row - auth < unauth) {
            return 54
        }
        return super.tableView(tableView, heightForRowAt: indexPath)
    }
    
    func themeSelected(_ index: Int) {
        SileoThemeManager.shared.activate(theme: SileoThemeManager.shared.themeList[index])
    }

}

extension SettingsViewController: ColorPickerDelegate {
    func colorPicker(_ colorPicker: ColorPickerViewController, didSelect color: UIColor) {
        SileoThemeManager.shared.setTintColor(color)
    }
}

@available(iOS 14.0, *)
extension SettingsViewController: UIColorPickerViewControllerDelegate {

    func colorPickerViewControllerDidFinish(_ viewController: UIColorPickerViewController) {
        SileoThemeManager.shared.setTintColor(viewController.selectedColor)
    }
    
}
