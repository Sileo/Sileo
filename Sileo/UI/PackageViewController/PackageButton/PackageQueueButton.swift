//
//  PackageQueueButton.swift
//  Sileo
//
//  Created by CoolStar on 4/20/20.
//  Copyright © 2020 CoolStar. All rights reserved.
//

import Foundation

class PackageQueueButton: PackageButton {
    public var viewControllerForPresentation: UIViewController?
    public var package: Package? {
        didSet {
            self.updatePurchaseStatus()
            self.updateInfo()
        }
    }
    public var overrideTitle: String = ""
    private var installedPackage: Package?
    
    override func setup() {
        super.setup()
        
        self.updateButton(title: "Get")
        self.addTarget(self, action: #selector(PackageQueueButton.buttonTapped(_:)), for: .touchUpInside)
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(PackageQueueButton.updateInfo),
                                               name: DownloadManager.reloadNotification,
                                               object: nil)
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(PackageQueueButton.updateInfo),
                                               name: DownloadManager.lockStateChangeNotification,
                                               object: nil)
        
        let longPressGesture = UILongPressGestureRecognizer(target: self, action: #selector(PackageQueueButton.handleBtnLongPressGesture(_:)))
        self.addGestureRecognizer(longPressGesture)
    }
    
    @objc func handleBtnLongPressGesture(_ recognizer: UILongPressGestureRecognizer) {
        if self.traitCollection.forceTouchCapability != .available {
            if recognizer.state == .began {
                self.showDowngradePrompt(recognizer)
            }
        }
    }
    
    func showDowngradePrompt(_ sender: Any?) {
        guard let package = package,
            !package.commercial else {
            return
        }
        let downgradePrompt = UIAlertController(title: String(localizationKey: "Select Version"),
                                                message: String(localizationKey: "Select the version of the package to install"),
                                                preferredStyle: .actionSheet)
        let allVersionsSorted = package.allVersions.sorted(by: { obj1, obj2 -> Bool in
            if DpkgWrapper.isVersion(obj1.version, greaterThan: obj2.version) {
                return true
            }
            return false
        })
        for package in allVersionsSorted {
            if (package.sourceRepo?.rawURL.hasPrefix("https://") == true ||
                package.sourceRepo?.rawURL.hasPrefix("http://") == true)
                && package.filename != nil && package.size != nil {
                downgradePrompt.addAction(UIAlertAction(title: package.version, style: .default, handler: { (_: UIAlertAction) in
                    let downloadManager = DownloadManager.shared
                    let queueFound = downloadManager.find(package: package)
                    if queueFound != .none {
                        //but it's a already queued! user changed his mind about installing this new package => nuke it from the queue
                        downloadManager.remove(package: package, queue: queueFound)
                    }

                    downloadManager.add(package: package, queue: .installations)
                    downloadManager.reloadData(recheckPackages: true)
                }))
            }
         }

        let cancelAction = UIAlertAction(title: String(localizationKey: "Package_Cancel_Action"), style: .cancel, handler: nil)
        downgradePrompt.addAction(cancelAction)
        if UIDevice.current.userInterfaceIdiom == .pad {
            downgradePrompt.popoverPresentationController?.sourceView = self
        }
        let tintColor = self.tintColor
        downgradePrompt.view.tintColor = tintColor
        viewControllerForPresentation?.present(downgradePrompt, animated: true, completion: {
            downgradePrompt.view.tintColor = tintColor
        })
    }
    
    @objc func updateInfo() {
        guard let package = package else {
            self.isEnabled = false
            return
        }
        installedPackage = PackageListManager.shared.installedPackage(identifier: package.package)
            
        let queueFound = DownloadManager.shared.find(package: package)
        var prominent = false
        if !overrideTitle.isEmpty {
            self.updateButton(title: overrideTitle)
        } else if queueFound != .none {
            self.updateButton(title: String(localizationKey: "Package_Queue_Action"))
        } else if installedPackage != nil {
            self.updateButton(title: String(localizationKey: "Package_Modify_Action"))
        } else {
            self.updateButton(title: String(localizationKey: "Package_Get_Action"))
            prominent = true
        }
        
        self.isProminent = prominent
        self.isEnabled = !DownloadManager.shared.lockedForInstallation
    }
    
    func updatePurchaseStatus() {
        if !(package?.commercial ?? false) {
            return
        }
        self.isEnabled = false
    }
    
    func updateButton(title: String) {
        self.setTitle(title.uppercased(), for: .normal)
    }
    
    func previewActionItems() -> [UIPreviewAction] {
        guard let package = self.package else {
                return []
        }
        var actionItems: [UIPreviewAction] = []

        let downloadManager = DownloadManager.shared

        let queueFound = downloadManager.find(package: package)
        if let installedPackage = installedPackage {
            if package.commercial {
                var repo: Repo?
                for repoEntry in RepoManager.shared.repoList {
                    if repoEntry.rawEntry == package.sourceFile {
                        repo = repoEntry
                    }
                 }
                if package.filename != nil && repo != nil {
                    if DpkgWrapper.isVersion(package.version, greaterThan: installedPackage.version) {
                        let action = UIPreviewAction(title: String(localizationKey: "Package_Upgrade_Action"), style: .default) { _, _  in
                            if queueFound != .none {
                                downloadManager.remove(package: package, queue: queueFound)
                            }

                            downloadManager.add(package: package, queue: .upgrades)
                            downloadManager.reloadData(recheckPackages: true)
                        }
                        actionItems.append(action)
                    } else if package.version == installedPackage.version {
                        let action = UIPreviewAction(title: String(localizationKey: "Package_Reinstall_Action"), style: .default) { _, _  in
                            if queueFound != .none {
                                downloadManager.remove(package: package, queue: queueFound)
                            }

                            downloadManager.add(package: package, queue: .installations)
                            downloadManager.reloadData(recheckPackages: true)
                        }
                        actionItems.append(action)
                    }
                }
                let action = UIPreviewAction(title: String(localizationKey: "Package_Uninstall_Action"), style: .default) { _, _  in
                    downloadManager.add(package: package, queue: .uninstallations)
                    downloadManager.reloadData(recheckPackages: true)
                }
                actionItems.append(action)
            }
        } else {
            //here's new packages not yet queued
            if package.commercial {
            } else {
                let action = UIPreviewAction(title: String(localizationKey: "Package_Get_Action"), style: .default) { _, _  in
                    //here's new packages not yet queued & FREE
                    downloadManager.add(package: package, queue: .installations)
                    downloadManager.reloadData(recheckPackages: true)
                }
                actionItems.append(action)
            }
        }
        return actionItems
    }
    
    @objc func buttonTapped(_ sender: Any?) {
        guard let package = self.package else {
                return
        }
        let downloadManager = DownloadManager.shared

        let queueFound = downloadManager.find(package: package)
        if queueFound != .none {
            //but it's a already queued! user changed his mind about installing this new package => nuke it from the queue
            TabBarController.singleton?.presentPopupController()
            downloadManager.reloadData(recheckPackages: true)
        } else if let installedPackage = installedPackage {
            //road clear to modify an installed package, now we gotta decide what modification
            let downloadPopup: UIAlertController! = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
            if !package.commercial {
                var repo: Repo?
                for repoEntry in RepoManager.shared.repoList {
                    if repoEntry.rawEntry == package.sourceFile {
                        repo = repoEntry
                    }
                 }
                if package.filename != nil && repo != nil {
                    if DpkgWrapper.isVersion(package.version, greaterThan: installedPackage.version) {
                        let upgradeAction = UIAlertAction(title: String(localizationKey: "Package_Upgrade_Action"),
                                                          style: .default) { _ in
                            downloadManager.add(package: package, queue: .upgrades)
                            downloadManager.reloadData(recheckPackages: true)
                        }
                        downloadPopup.addAction(upgradeAction)
                    } else if package.version == installedPackage.version {
                        let reinstallAction = UIAlertAction(title: String(localizationKey: "Package_Reinstall_Action"),
                                                            style: .default) { _ in
                            downloadManager.add(package: package, queue: .installations)
                            downloadManager.reloadData(recheckPackages: true)
                        }
                        downloadPopup.addAction(reinstallAction)
                    }
                }
            }

            let removeAction = UIAlertAction(title: String(localizationKey: "Package_Uninstall_Action"), style: .default, handler: { _ in
                downloadManager.add(package: package, queue: .uninstallations)
                downloadManager.reloadData(recheckPackages: true)
            })
            downloadPopup.addAction(removeAction)
            let cancelAction: UIAlertAction! = UIAlertAction(title: String(localizationKey: "Package_Cancel_Action"), style: .cancel)
            downloadPopup.addAction(cancelAction)
            if UIDevice.current.userInterfaceIdiom == .pad {
                downloadPopup.popoverPresentationController?.sourceView = self
            }
            let tintColor: UIColor! = self.tintColor
            if tintColor != nil {
                downloadPopup.view.tintColor = tintColor
            }
            self.viewControllerForPresentation?.present(downloadPopup, animated: true, completion: {
                if tintColor != nil {
                    downloadPopup.view.tintColor = tintColor
                }
            })
        } else {
            //here's new packages not yet queued
            if package.commercial  && !package.package.contains("/") {
            } else {
                //here's new packages not yet queued & FREE
                downloadManager.add(package: package, queue: .installations)
                downloadManager.reloadData(recheckPackages: true)
            }
        }
    }
}
