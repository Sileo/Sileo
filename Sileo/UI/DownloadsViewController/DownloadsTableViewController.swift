//
//  DownloadsTableViewController.swift
//  Sileo
//
//  Created by CoolStar on 8/3/19.
//  Copyright © 2019 CoolStar. All rights reserved.
//

import Foundation

class DownloadsTableViewController: SileoViewController {
    @IBOutlet var footerView: UIView?
    @IBOutlet var cancelButton: UIButton?
    @IBOutlet var confirmButton: UIButton?
    @IBOutlet var footerViewHeight: NSLayoutConstraint?
    @IBOutlet var tableView: UITableView?
    
    var transitionController = false
    var statusBarView: UIView?
    
    var upgrades: [DownloadPackage] = []
    var installations: [DownloadPackage] = []
    var uninstallations: [DownloadPackage] = []
    var installdeps: [DownloadPackage] = []
    var uninstalldeps: [DownloadPackage] = []
    var errors: [[String: Any]] = []
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let statusBarView = SileoRootView(frame: .zero)
        self.view.addSubview(statusBarView)
        self.statusBarView = statusBarView
        
        self.statusBarStyle = UIDevice.current.userInterfaceIdiom == .pad ? .default : .lightContent
        
        self.tableView?.separatorStyle = .none
        self.tableView?.separatorColor = UIColor(red: 234/255, green: 234/255, blue: 236/255, alpha: 1)
        self.tableView?.isEditing = true
        self.tableView?.clipsToBounds = true
        if UIDevice.current.userInterfaceIdiom == .phone {
            self.tableView?.contentInsetAdjustmentBehavior = .never
            self.tableView?.contentInset = UIEdgeInsets(top: 43, left: 0, bottom: 0, right: 0)
        }
        
        confirmButton?.layer.cornerRadius = 10
        
        confirmButton?.setTitle(String(localizationKey: "Queue_Confirm_Button"), for: .normal)
        cancelButton?.setTitle(String(localizationKey: "Queue_Clear_Button"), for: .normal)
        
        DownloadManager.shared.reloadData(recheckPackages: false)
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        
        guard let tableView = self.tableView,
            let cancelButton = self.cancelButton,
            let confirmButton = self.confirmButton,
            let statusBarView = self.statusBarView else {
                return
        }
        
        statusBarView.frame = CGRect(origin: .zero, size: CGSize(width: self.view.bounds.width, height: tableView.safeAreaInsets.top))
        
        cancelButton.tintColor = confirmButton.tintColor
        cancelButton.isHighlighted = confirmButton.isHighlighted
        confirmButton.tintColor = UINavigationBar.appearance().tintColor
        confirmButton.isHighlighted = confirmButton.isHighlighted
    }
    
    public func loadData() {
        let manager = DownloadManager.shared
        upgrades = manager.upgrades
        installations = manager.installations
        uninstallations = manager.uninstallations
        installdeps = manager.installdeps
        uninstalldeps = manager.uninstalldeps
        errors = manager.errors
    }
    
    public func reloadData() {
        self.loadData()
        
        self.tableView?.reloadData()
        self.reloadControlsOnly()
    }
    
    public func reloadControlsOnly() {
        let manager = DownloadManager.shared
        if manager.queuedPackages() > 0 {
            UIView.animate(withDuration: 0.25) {
                self.footerViewHeight?.constant = 128
                self.footerView?.alpha = 1
            }
        } else {
            UIView.animate(withDuration: 0.25) {
                self.footerViewHeight?.constant = 0
                self.footerView?.alpha = 0
            }
        }
        
        if manager.readyPackages() >= manager.installingPackages() &&
            manager.readyPackages() > 0 && manager.downloadingPackages() == 0 &&
            manager.errors.isEmpty {
            if !manager.lockedForInstallation {
                manager.lockedForInstallation = true
                
                let installController = InstallViewController(nibName: "InstallViewController", bundle: nil)
                manager.totalProgress = 0
                self.navigationController?.pushViewController(installController, animated: true)
                TabBarController.singleton?.presentPopupController()
            }
        }
        if manager.errors.isEmpty {
            self.confirmButton?.isEnabled = true
            self.confirmButton?.alpha = 1
        } else {
            self.confirmButton?.isEnabled = false
            self.confirmButton?.alpha = 0.5
        }
    }
    
    public func reloadDownload(package: Package?) {
        guard let package = package else {
            return
        }
        let dlPackage = DownloadPackage(package: package)
        var rawIndexPath: IndexPath?
        let installsAndDeps = installations + installdeps
        if installsAndDeps.contains(dlPackage) {
            rawIndexPath = IndexPath(row: installsAndDeps.firstIndex(of: dlPackage) ?? -1, section: 0)
        } else if upgrades.contains(dlPackage) {
            rawIndexPath = IndexPath(row: upgrades.firstIndex(of: dlPackage) ?? -1, section: 2)
        }
        guard let indexPath = rawIndexPath else {
            return
        }
        guard let cell = self.tableView?.cellForRow(at: indexPath) as? DownloadsTableViewCell else {
            return
        }
        cell.updateDownload()
        cell.layoutSubviews()
    }
    
    @IBAction func cancelQueued(_ sender: Any?) {
        DownloadManager.shared.cancelUnqueuedDownloads()
        TabBarController.singleton?.dismissPopupController()
        DownloadManager.shared.reloadData(recheckPackages: true)
    }
    
    @IBAction func confirmQueued(_ sender: Any?) {
        DownloadManager.shared.startUnqueuedDownloads()
        DownloadManager.shared.reloadData(recheckPackages: false)
    }
    
    override func accessibilityPerformEscape() -> Bool {
        TabBarController.singleton?.dismissPopupController()
        return true
    }
}

extension DownloadsTableViewController: UITableViewDataSource {
    func numberOfSections(in tableView: UITableView) -> Int {
        6
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch section {
        case 0:
            return installations.count + installdeps.count
        case 1:
            return uninstallations.count + uninstalldeps.count
        case 2:
            return upgrades.count
        case 3:
            return errors.count
        default:
            return 0
        }
    }
    
    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        if tableView.numberOfRows(inSection: section) == 0 {
            return nil
        }
        switch section {
        case 0:
            return String(localizationKey: "Queued_Install_Heading")
        case 1:
            return String(localizationKey: "Queued_Uninstall_Heading")
        case 2:
            return String(localizationKey: "Queued_Update_Heading")
        case 3:
            return String(localizationKey: "Download_Errors_Heading")
        default:
            return nil
        }
    }
    
    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        if (self.tableView?.numberOfRows(inSection: section) ?? 0) > 0 {
            let headerView = UIView(frame: CGRect(origin: .zero, size: CGSize(width: 320, height: 36)))
            
            let backgroundView = SileoRootView(frame: CGRect(x: 0, y: -24, width: 320, height: 60))
            backgroundView.autoresizingMask = [.flexibleWidth, .flexibleBottomMargin]
            headerView.addSubview(backgroundView)
            
            if let text = self.tableView(tableView, titleForHeaderInSection: section) {
                let titleView = SileoLabelView(frame: CGRect(x: 16, y: 0, width: 320, height: 28))
                titleView.font = UIFont.systemFont(ofSize: 22, weight: .bold)
                titleView.text = text
                titleView.autoresizingMask = .flexibleWidth
                headerView.addSubview(titleView)
                
                let separatorView = SileoSeparatorView(frame: CGRect(x: 16, y: 35, width: 304, height: 1))
                separatorView.autoresizingMask = .flexibleWidth
                headerView.addSubview(separatorView)
            }
            return headerView
        }
        return nil
    }
    
    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        if self.tableView(tableView, numberOfRowsInSection: section) > 0 {
            return 36
        }
        return 0
    }
    
    func tableView(_ tableView: UITableView, viewForFooterInSection section: Int) -> UIView? {
        //Do not delete this, it's so the tableview doesn't display separator lines beyond the last populated row.
        return UIView()
    }
    
    func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        8
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        58
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cellIdentifier = "DownloadsTableViewCellIdentifier"
        let cell = (tableView.dequeueReusableCell(withIdentifier: cellIdentifier) as? DownloadsTableViewCell) ??
            DownloadsTableViewCell(style: .subtitle, reuseIdentifier: cellIdentifier)
        
        if indexPath.section == 3 {
            // Error listing
            let error = errors[indexPath.row]
            if let package = error["package"] as? Package {
                cell.package = DownloadPackage(package: package)
            }
            cell.shouldHaveDownload = false
            if let key = error["key"] as? String,
                let otherPkg = error["otherPkg"] as? String {
                cell.errorDescription = "\(key) \(otherPkg)"
            }
            cell.download = nil
        } else {
            // Normal operation listing
            var array: [DownloadPackage] = []
            switch indexPath.section {
            case 0:
                array = installations + installdeps
            case 1:
                array = uninstallations + uninstalldeps
            case 2:
                array = upgrades
            default:
                break
            }
            
            cell.package = array[indexPath.row]
            cell.shouldHaveDownload = indexPath.section == 0 || indexPath.section == 2
            cell.errorDescription = nil
            cell.download = nil
            if cell.shouldHaveDownload {
                cell.download = DownloadManager.shared.download(package: cell.package?.package.package ?? "")
            }
        }
        cell.icon = UIImage(named: "Tweak Icon")
        return cell
    }
}

extension DownloadsTableViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        if indexPath.section == 3 {
            return false
        }
        var array: [DownloadPackage] = []
        switch indexPath.section {
        case 0:
            array = installations
        case 1:
            array = uninstallations
        case 2:
            array = upgrades
        default:
            break
        }
        if indexPath.row >= array.count {
            return false
        }
        return true
    }
    
    func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == .delete {
            var queue: DownloadManagerQueue = .none
            var array: [DownloadPackage] = []
            switch indexPath.section {
            case 0:
                array = installations
                queue = .installations
            case 1:
                array = uninstallations
                queue = .uninstallations
            case 2:
                array = upgrades
                queue = .upgrades
            default:
                break
            }
            if indexPath.section == 3 || indexPath.row >= array.count {
                fatalError("Invalid section/row (not editable)")
            }
            
            let downloadManager = DownloadManager.shared
            downloadManager.remove(downloadPackage: array[indexPath.row], queue: queue)
            self.loadData()
            tableView.deleteRows(at: [indexPath], with: .fade)
            
            downloadManager.reloadData(recheckPackages: true)
        }
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
    }
}
