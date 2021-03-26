//
//  PackageListViewController.swift
//  Sileo
//
//  Created by CoolStar on 8/14/19.
//  Copyright © 2019 CoolStar. All rights reserved.
//

import Foundation
import os

class PackageListViewController: SileoViewController, UIGestureRecognizerDelegate {
    @IBOutlet var collectionView: UICollectionView?
    @IBOutlet var downloadsButton: UIBarButtonItem?
    
    @IBInspectable var showSearchField: Bool = false
    @IBInspectable var showUpdates: Bool = false
    @IBInspectable var showWishlist: Bool = false
    @IBInspectable var showProvisional: Bool = false
    
    @IBInspectable public var packagesLoadIdentifier: String = ""
    public var repoContext: Repo?
    
    private var packages: [Package] = []
    private var availableUpdates: [Package] = []
    private var searchCache: [String: [Package]] = [:]
    private var provisionalPackages: [ProvisionalPackage] = []
    
    private var displaySettings = false
    
    private let mutexLock = DispatchSemaphore(value: 1)
    private var updatingCount = 0
    private var refreshEnabled = false
    
    @IBInspectable var localizableTitle: String = ""
    
    var searchController: UISearchController?
    
    @objc func updateSileoColors() {
        self.statusBarStyle = .default
    }
    
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        updateSileoColors()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        updateSileoColors()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        self.navigationController?.navigationBar._hidesShadow = true
        
        guard #available(iOS 13, *) else {
            if showSearchField {
                self.navigationItem.hidesSearchBarWhenScrolling = false
            }
            return
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        self.navigationController?.navigationBar._hidesShadow = false
        
        guard let visibleCells = collectionView?.visibleCells else {
            return
        }
        for cell in visibleCells {
            if let packageCell = cell as? PackageCollectionViewCell {
                packageCell.hideSwipe(animated: false)
            }
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        
        if showWishlist {
            let exportBtn = UIBarButtonItem(title: String(localizationKey: "Export"), style: .plain, target: self, action: #selector(self.exportButtonClicked(_:)))
            
            #if targetEnvironment(simulator) || TARGET_SANDBOX
            
            let testQueueBtn = UIBarButtonItem(title: "Test Queue", style: .plain, target: self, action: #selector(self.addTestQueue(_:)))
            self.navigationItem.leftBarButtonItems = [exportBtn, testQueueBtn]
            
            #else
            
            self.navigationItem.leftBarButtonItem = exportBtn
            
            #endif
            
            let wishlistBtn = UIBarButtonItem(title: String(localizationKey: "Wishlist"), style: .plain, target: self, action: #selector(self.showWishlist(_:)))
            self.navigationItem.rightBarButtonItem = wishlistBtn
        }
        
        if packagesLoadIdentifier.contains("--wishlist") {
            NotificationCenter.default.addObserver(self, selector: #selector(self.reloadData), name: WishListManager.changeNotification, object: nil)
        }
        
        if !localizableTitle.isEmpty {
            self.title = String(localizationKey: localizableTitle)
        }
        
        NotificationCenter.default.addObserver(self, selector: #selector(self.reloadData),
                                               name: PackageListManager.reloadNotification,
                                               object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(self.reloadData),
                                               name: DownloadManager.reloadNotification,
                                               object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(self.reloadData),
                                               name: DownloadManager.lockStateChangeNotification,
                                               object: nil)
        if self.showUpdates {
            NotificationCenter.default.addObserver(self, selector: #selector(self.reloadUpdates),
                                                   name: PackageListManager.prefsNotification,
                                                   object: nil)
        }
        
        // A value of exactly 17.0 (the default) causes the text to auto-shrink
        UITextField.appearance(whenContainedInInstancesOf: [UISearchBar.self]).defaultTextAttributes = [
            NSAttributedString.Key.font: UIFont.systemFont(ofSize: 17.01)
        ]
        
        searchController = UISearchController(searchResultsController: nil)
        searchController?.searchBar.placeholder = String(localizationKey: "Package_Search.Placeholder")
        searchController?.searchBar.delegate = self
        searchController?.searchResultsUpdater = self
        searchController?.obscuresBackgroundDuringPresentation = false
        searchController?.hidesNavigationBarDuringPresentation = true
        
        self.navigationController?.navigationBar.superview?.tag = WHITE_BLUR_TAG
        
        self.navigationItem.hidesSearchBarWhenScrolling = false
        self.navigationItem.searchController = searchController
        self.definesPresentationContext = true
        
        var sbTextField: UITextField?
        if #available(iOS 13, *) {
            sbTextField = searchController?.searchBar.searchTextField
        } else {
            sbTextField = searchController?.searchBar.value(forKey: "_searchField") as? UITextField
        }
        sbTextField?.font = UIFont.systemFont(ofSize: 13)
        
        let tapRecognizer = UITapGestureRecognizer(target: searchController?.searchBar, action: #selector(UISearchBar.resignFirstResponder))
        tapRecognizer.cancelsTouchesInView = true
        tapRecognizer.delegate = self
        
        if let collectionView = collectionView {
            collectionView.addGestureRecognizer(tapRecognizer)
            collectionView.register(UINib(nibName: "PackageCollectionViewCell", bundle: nil),
                                    forCellWithReuseIdentifier: "PackageListViewCellIdentifier")
        
            let flowLayout = collectionView.collectionViewLayout as? UICollectionViewFlowLayout
            flowLayout?.sectionHeadersPinToVisibleBounds = true
        
            collectionView.register(UINib(nibName: "PackageListHeader", bundle: nil),
                                    forSupplementaryViewOfKind: UICollectionView.elementKindSectionHeader,
                                    withReuseIdentifier: "PackageListHeader")
            collectionView.register(UINib(nibName: "PackageListHeaderBlank", bundle: nil),
                                    forSupplementaryViewOfKind: UICollectionView.elementKindSectionHeader,
                                    withReuseIdentifier: "PackageListHeaderBlank")
        
            self.registerForPreviewing(with: self, sourceView: collectionView)
        }
        DispatchQueue.global(qos: .default).async {
            let packageMan = PackageListManager.shared
            
            if !self.showSearchField {
                let pkgs = packageMan.packagesList(loadIdentifier: self.packagesLoadIdentifier,
                                                   repoContext: self.repoContext,
                                                   sortPackages: true,
                                                   lookupTable: self.searchCache) ?? []
                self.packages = pkgs
                self.searchCache[""] = pkgs
            }
            if self.showUpdates {
                self.availableUpdates = packageMan.availableUpdates().map({ $0.0 })
            }
            
            let updatesNotIgnored = self.availableUpdates.filter({ $0.wantInfo != .hold })
            DispatchQueue.main.async {
                if !updatesNotIgnored.isEmpty {
                    self.navigationController?.tabBarItem.badgeValue = String(format: "%ld", updatesNotIgnored.count)
                } else {
                    self.navigationController?.tabBarItem.badgeValue = nil
                }
                
                self.collectionView?.reloadData()
            }
        }
    }
    
    #if targetEnvironment(simulator) || TARGET_SANDBOX
    @objc func addTestQueue(_ : Any?) {
        let testQueue = ["applist", "apt", "apt-key", "apt-lib", "base",
                         "bash", "berkeleydb", "bzip2", "ca.menushka.onenotify",
                         "co.dynastic.tsssaver", "com.ahmad.badgemenot", "com.ahmadnagy.mint4",
                         "com.anemonetheming.anemone3", "com.anemonetheming.anemone3-extsb",
                         "com.atwiiks.betterccxi", "com.atwiiks.betterccxiweather", "com.cc.haptickeys",
                         "com.chpwn.iconsupport", "com.cokepokes.fucklargetitles", "com.cpdigitaldarkroom.barmoji",
                         "com.cpdigitaldarkroom.cuttlefish", "com.creaturecoding.libcspreferences",
                         "com.creaturecoding.shuffle", "com.creaturesurvive.libcscolorpicker", "com.donbytyqi.tinybanners",
                         "com.easy-z.npf", "com.ex.libsubstitute", "com.exile90.icleanerpro", "com.foxfort.amazonite",
                         "com.foxfort.darkgmaps", "com.foxfort.darksounds", "com.foxfort.foxforttools",
                         "com.foxfort.libfoxfortsplash", "com.foxfort.libfoxfortutils", "com.fpt.saw",
                         "com.gabehern.goji", "com.gilshahar7.pearlretry", "com.golddavid.colorbadges-new",
                         "com.golddavid.colorbanners2-new", "com.ikilledappl3.colormyyccmodules",
                         "com.imkpatil.nooldernotificationstext", "com.ioscreatix.sugarcane", "com.ioscreatix.weathervane",
                         "com.irepo.boxy3", "com.julioverne.goodwifi", "com.junesiphone.sileonobanner",
                         "com.karimo299.leavemealone", "com.laughingquoll.cowbell", "com.laughingquoll.modulus",
                         "com.laughingquoll.noctis12", "com.laughingquoll.prefixui", "com.level3tjg.noartshadow",
                         "com.linusyang.localeutf8", "com.macciti.amury", "com.matchstic.reprovision",
                         "com.midnightchips.ldrun", "com.modmyi.libswift4", "com.muirey03.13hud",
                         "com.muirey03.powermodule", "com.muirey03.workffs", "com.muirey03.zenith",
                         "com.niceios.nicebarx", "com.opa334.ccsupport", "com.quackdev.crayolax",
                         "com.r0wdrunner.cleantabs", "com.r333d.cylinder", "com.revulate.groovetube",
                         "com.revulate.harmony", "com.rpetrich.rocketbootstrap", "com.satvikb.selectionplus",
                         "com.shiftcmdk.pencilchargingindicator", "com.smokin1337.fugap",
                         "com.spark.libsparkapplist", "com.spark.lowbatterybanner", "com.spark.noccbar",
                         "com.spark.nolowpowerautolock", "com.spark.nomoresmallapps", "com.spark.notchless",
                         "com.thetimeloop.bohemic", "com.tigisoftware.filza", "com.tonyk7.0vigilate",
                         "com.udevs.dictmojix", "com.wh0ba.ytminibarx", "com.yadkin.twitternoads",
                         "com.yourepo.cloudftl.fudock", "com.yourepo.kingmehu.perfecttimexs",
                         "coreutils", "coreutils-bin", "cydia", "darwintools", "debianutils",
                         "diffutils", "dpkg", "findutils", "firmware", "firmware-sbin", "flex3beta",
                         "gnupg", "grep", "gzip", "jp.ashikase.libpackageinfo", "jp.ashikase.techsupport",
                         "jp.soh.fullmusic11paid", "libressl", "live.calicocat.pagebar", "lzma",
                         "me.alfhaily.cercube", "me.nepeta.libcolorpicker", "me.nepeta.libnepeta",
                         "me.nepeta.notifica", "me.nepeta.unsub", "mobilesubstrate", "ncurses",
                         "rc", "openssh", "org.coolstar.sileo", "org.coolstar.tweakinject", "org.swift.libswift",
                         "org.thebigboss.palert", "p7zip", "pincrush", "preferenceloader", "profile.d",
                         "sed", "shell-cmds", "system-cmds", "tar", "uikittools", "unrar", "unzip",
                         "ws.hbang.common", "ws.hbang.newterm2", "xyz.royalapps.jellyfish", "xyz.xninja.systeminfo", "zip"]
        
        for packageID in testQueue {
            guard let package = PackageListManager.shared.newestPackage(identifier: packageID),
                  package.filename != nil
            else {
                continue
            }
            
            DownloadManager.shared.add(package: package, queue: .installations)
        }
        
        DownloadManager.shared.reloadData(recheckPackages: true)
    }
    #endif
    
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        searchController?.searchBar.isFirstResponder ?? false
    }
    
    func controller(package: Package) -> PackageViewController {
        let packageViewController = PackageViewController(nibName: "PackageViewController", bundle: nil)
        packageViewController.package = package
        return packageViewController
    }
    
    func controller(indexPath: IndexPath) -> PackageViewController {
        if showUpdates && indexPath.section == 0 {
            return controller(package: availableUpdates[indexPath.row])
        } else {
            return controller(package: packages[indexPath.row])
        }
    }
    
    func controller(provisional: ProvisionalPackage) -> PackageViewController? {
        guard let package = CanisterResolver.package(provisional) else { return nil }
        let packageViewController = PackageViewController(nibName: "PackageViewController", bundle: nil)
        packageViewController.package = package
        return packageViewController
    }
    
    @objc func reloadData() {
        self.searchCache = [:]
        if showUpdates {
            self.reloadUpdates()
        } else {
            if let searchController = self.searchController {
                self.updateSearchResults(for: searchController)
            }
        }
    }
    
    @objc func reloadUpdates() {
        if showUpdates {
            DispatchQueue.global(qos: .default).async {
                let rawUpdates = PackageListManager.shared.availableUpdates()
                self.availableUpdates = rawUpdates.map({ $0.0 })
                let updatesNotIgnored = rawUpdates.filter({ $0.1?.wantInfo != .hold })
                DispatchQueue.main.async {
                    if !updatesNotIgnored.isEmpty {
                        self.navigationController?.tabBarItem.badgeValue = String(format: "%ld", updatesNotIgnored.count)
                        UIApplication.shared.applicationIconBadgeNumber = updatesNotIgnored.count
                    } else {
                        self.navigationController?.tabBarItem.badgeValue = nil
                        UIApplication.shared.applicationIconBadgeNumber = 0
                    }
                    if self.refreshEnabled {
                        self.collectionView?.reloadSections(IndexSet(integer: 0))
                    }
                    if let searchController = self.searchController {
                        self.updateSearchResults(for: searchController)
                    }
                }
            }
        }
    }
    
    @objc func exportButtonClicked(_ button: UIButton?) {
        let alert = UIAlertController(title: String(localizationKey: "Export"),
                                      message: String(localizationKey: "Export_Packages"),
                                      preferredStyle: .alert)
        
        let defaultAction = UIAlertAction(title: String(localizationKey: "Export_Yes"), style: .default, handler: { _ in
            self.copyPackages()
        })
        
        let cancelAction = UIAlertAction(title: String(localizationKey: "Export_No"), style: .cancel, handler: { _ in
        })
        
        alert.addAction(defaultAction)
        alert.addAction(cancelAction)
        present(alert, animated: true)
    }
    
    func copyPackages() {
        var bodyFromArray = ""
        let packages = self.packages
        for package in packages {
            guard let packageName = package.name else {
                continue
            }
            let packageVersion = package.version
            
            bodyFromArray += "\(packageName): \(packageVersion)\n"
        }
        if let subRange = Range<String.Index>(NSRange(location: bodyFromArray.count - 1, length: 1),
                                              in: bodyFromArray) {
            bodyFromArray.removeSubrange(subRange)
        }
        let pasteboard = UIPasteboard.general
        pasteboard.string = bodyFromArray
    }
    
    @objc func showWishlist(_ sender: Any?) {
        let wishlistController = PackageListViewController(nibName: "PackageListViewController", bundle: nil)
        wishlistController.title = String(localizationKey: "Wishlist")
        wishlistController.packagesLoadIdentifier = "--wishlist"
        self.navigationController?.pushViewController(wishlistController, animated: true)
    }
    
    @objc func upgradeAllClicked(_ sender: Any?) {
        PackageListManager.shared.upgradeAll()
    }
    
    @objc func sortPopup(sender: UIView?) {
        let alertController = UIAlertController(title: String(localizationKey: "Sort_By"), message: nil, preferredStyle: .actionSheet)
        alertController.addAction(UIAlertAction(title: String(localizationKey: "Sort_Name"), style: .default, handler: { _ in
            UserDefaults.standard.set(false, forKey: "sortInstalledByDate")
            if let searchController = self.searchController {
                self.updateSearchResults(for: searchController)
            }
            self.dismiss(animated: true, completion: nil)
        }))
        alertController.addAction(UIAlertAction(title: String(localizationKey: "Sort_Date"), style: .default, handler: { _ in
            UserDefaults.standard.set(true, forKey: "sortInstalledByDate")
            if let searchController = self.searchController {
                self.updateSearchResults(for: searchController)
            }
            self.dismiss(animated: true, completion: nil)
        }))
        alertController.addAction(UIAlertAction(title: String(localizationKey: "Cancel"), style: .cancel, handler: { _ in
            self.dismiss(animated: true, completion: nil)
        }))
        alertController.modalPresentationStyle = .popover
        alertController.popoverPresentationController?.sourceView = sender
        self.present(alertController, animated: true, completion: nil)
    }
}

extension PackageListViewController: UICollectionViewDataSource {
    func numberOfSections(in collectionView: UICollectionView) -> Int {
        refreshEnabled = true
        var count = 1
        if showUpdates { count += 1 }
        if showProvisional { count += 1 }
        return count
    }
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        if showUpdates && section == 0 {
            return availableUpdates.count
        } else if section == 2 || (section == 1 && showProvisional) {
            return provisionalPackages.count
        }
        return packages.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cellIdentifier = "PackageListViewCellIdentifier"
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: cellIdentifier, for: indexPath)
        if let packageCell = cell as? PackageCollectionViewCell {
            if showUpdates && indexPath.section == 0 {
                packageCell.targetPackage = availableUpdates[indexPath.row]
                packageCell.provisionalTarget = nil
            } else if indexPath.section == 2 || (indexPath.section == 1 && showProvisional) {
                packageCell.provisionalTarget = provisionalPackages[indexPath.row]
                packageCell.targetPackage = nil
            } else {
                packageCell.targetPackage = packages[indexPath.row]
                packageCell.provisionalTarget = nil
            }
        }
        return cell
    }
    
    func collectionView(_ collectionView: UICollectionView, viewForSupplementaryElementOfKind kind: String, at indexPath: IndexPath) -> UICollectionReusableView {
        if showUpdates {
            if indexPath.section == 0 && availableUpdates.isEmpty {
                return UICollectionReusableView()
            }
            if kind == UICollectionView.elementKindSectionHeader {
                guard let headerView = collectionView.dequeueReusableSupplementaryView(ofKind: kind,
                                                                                       withReuseIdentifier: "PackageListHeader",
                                                                                       for: indexPath) as? PackageListHeader
                else {
                    return UICollectionReusableView()
                }
                
                if indexPath.section == 0 {
                    headerView.label?.text = String(localizationKey: "Updates_Heading")
                    headerView.actionText = String(localizationKey: "Upgrade_All_Button")
                    headerView.sortButton?.isHidden = true
                    headerView.separatorView?.isHidden = true
                    headerView.upgradeButton?.addTarget(self, action: #selector(self.upgradeAllClicked(_:)), for: .touchUpInside)
                } else {
                    headerView.label?.text = String(localizationKey: "Installed_Heading")
                    headerView.actionText = nil
                    headerView.sortButton?.isHidden = false
                    
                    if UserDefaults.standard.bool(forKey: "sortInstalledByDate") {
                        headerView.sortButton?.setTitle(String(localizationKey: "Sort_Date"), for: .normal)
                    } else {
                        headerView.sortButton?.setTitle(String(localizationKey: "Sort_Name"), for: .normal)
                    }
                    headerView.sortButton?.addTarget(self, action: #selector(self.sortPopup(sender:)), for: .touchUpInside)
                    
                    headerView.separatorView?.isHidden = false
                }
                return headerView
            }
        } else if showProvisional {
            if (indexPath.section == 0 && packages.isEmpty) || (indexPath.section == 1 && provisionalPackages.isEmpty) {
                if kind == UICollectionView.elementKindSectionHeader {
                    let headerView = collectionView.dequeueReusableSupplementaryView(ofKind: kind,
                                                                                     withReuseIdentifier: "PackageListHeaderBlank",
                                                                                     for: indexPath)
                    return headerView
                }
            }
            guard let headerView = collectionView.dequeueReusableSupplementaryView(ofKind: kind,
                                                                                   withReuseIdentifier: "PackageListHeader",
                                                                                   for: indexPath) as? PackageListHeader
            else {
                return UICollectionReusableView()
            }
            headerView.actionText = nil
            headerView.separatorView?.isHidden = false
            headerView.sortButton?.isHidden = true
            headerView.upgradeButton?.isHidden = true
            
            if indexPath.section == 0 && !packages.isEmpty {
                headerView.label?.text = "Installed Repos"
                return headerView
            } else if indexPath.section == 1 && !provisionalPackages.isEmpty {
                headerView.label?.text = "External Repos"
                return headerView
            } else {
                if kind == UICollectionView.elementKindSectionHeader {
                    let headerView = collectionView.dequeueReusableSupplementaryView(ofKind: kind,
                                                                                     withReuseIdentifier: "PackageListHeaderBlank",
                                                                                     for: indexPath)
                    return headerView
                }
            }
        } else {
            if kind == UICollectionView.elementKindSectionHeader {
                let headerView = collectionView.dequeueReusableSupplementaryView(ofKind: kind,
                                                                                 withReuseIdentifier: "PackageListHeaderBlank",
                                                                                 for: indexPath)
                return headerView
            }
        }
        return UICollectionReusableView()
    }
}

extension PackageListViewController: UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        collectionView.deselectItem(at: indexPath, animated: true)
        if indexPath.section == 1 && showProvisional {
            let pro = provisionalPackages[indexPath.row]
            guard let pvc = self.controller(provisional: pro) else { return }
            self.navigationController?.pushViewController(pvc, animated: true)
        } else {
            let packageViewController = self.controller(indexPath: indexPath)
            self.navigationController?.pushViewController(packageViewController, animated: true)
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, didDeselectItemAt indexPath: IndexPath) {
        
    }
}

extension PackageListViewController: UICollectionViewDelegateFlowLayout {
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, referenceSizeForHeaderInSection section: Int) -> CGSize {
        if showUpdates {
            if section == 0 && availableUpdates.isEmpty {
                return .zero
            }
            if section == 1 && displaySettings {
                return CGSize(width: collectionView.bounds.width, height: 109)
            }
            return CGSize(width: collectionView.bounds.width, height: 65)
        } else if showProvisional {
            if (section == 0 && packages.isEmpty) || (section == 1 && provisionalPackages.isEmpty) {
                return .zero
            }
            return CGSize(width: collectionView.bounds.width, height: 65)
        } else {
            return CGSize(width: collectionView.bounds.width, height: 9)
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        var width = collectionView.bounds.size.width
        if UIDevice.current.userInterfaceIdiom == .pad || UIApplication.shared.statusBarOrientation.isLandscape {
            if width > 330 {
                width = 330
            }
        }
        return CGSize(width: width, height: 73)
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumLineSpacingForSectionAt section: Int) -> CGFloat {
        0
    }
}

extension PackageListViewController: UIViewControllerPreviewingDelegate {
    func previewingContext(_ previewingContext: UIViewControllerPreviewing, viewControllerForLocation location: CGPoint) -> UIViewController? {
        guard let indexPath = collectionView?.indexPathForItem(at: location) else {
            return nil
        }
        
        let packageViewController = self.controller(indexPath: indexPath)
        return packageViewController
    }
    
    func previewingContext(_ previewingContext: UIViewControllerPreviewing, commit viewControllerToCommit: UIViewController) {
        self.navigationController?.pushViewController(viewControllerToCommit, animated: true)
    }
}

@available(iOS 13.0, *)
extension PackageListViewController {
    func collectionView(_ collectionView: UICollectionView, contextMenuConfigurationForItemAt indexPath: IndexPath, point: CGPoint) -> UIContextMenuConfiguration? {
        let packageViewController = self.controller(indexPath: indexPath)
        let menuItems = packageViewController.actions()

        return UIContextMenuConfiguration(identifier: nil,
                                          previewProvider: {
                                            packageViewController
                                          },
                                          actionProvider: { _ in
                                            UIMenu(title: "", options: .displayInline, children: menuItems)
                                          })
    }
    
    func collectionView(_ collectionView: UICollectionView, willPerformPreviewActionForMenuWith configuration: UIContextMenuConfiguration, animator: UIContextMenuInteractionCommitAnimating) {
        if let previewController = animator.previewViewController {
            animator.addAnimations {
                self.show(previewController, sender: self)
            }
        }
    }
}

extension PackageListViewController: UISearchBarDelegate {
    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        guard let text = searchBar.text,
              !text.isEmpty,
              showProvisional
        else {
            return
        }
        CanisterResolver.shared.fetch(text) { 
            DispatchQueue.main.async { self.updateSearchResults(for: self.searchController ?? UISearchController()) }
        }
    }
    
    private func updateProvisional() {
        let text = (searchController?.searchBar.text ?? "").lowercased()
        if text.isEmpty { return self.provisionalPackages.removeAll() }
        let all = PackageListManager.shared.allPackages ?? []
        self.provisionalPackages = CanisterResolver.shared.packages.filter {(package: ProvisionalPackage) -> Bool in
            let search = (package.name?.lowercased().contains(text) ?? false) ||
                (package.identifier?.lowercased().contains(text) ?? false) ||
                (package.description?.lowercased().contains(text) ?? false) ||
                (package.author?.lowercased().contains(text) ?? false)
            if !search { return false }
            let newer = DpkgWrapper.isVersion(package.version ?? "", greaterThan: all.first(where: { $0.packageID == package.identifier })?.version ?? "")
            let localRepo = all.contains(where: { package.identifier == $0.packageID })
            if localRepo { return newer }
            return true
        }
    }
}

extension PackageListViewController: UISearchResultsUpdating {
    func updateSearchResults(for searchController: UISearchController) {
        let searchBar = searchController.searchBar
        var packagesLoadIdentifier = self.packagesLoadIdentifier
        if searchBar.text?.isEmpty ?? true {
            let emptyResults = self.searchCache[""]
            self.searchCache = [:]
            self.searchCache[""] = emptyResults
            if showSearchField {
                if !packages.isEmpty {
                    packages = []
                    collectionView?.reloadSections(IndexSet(integer: 0))
                }
                if !provisionalPackages.isEmpty {
                    provisionalPackages = []
                    collectionView?.reloadSections(IndexSet(integer: 1))
                }
                return
            }
        } else {
            if !packagesLoadIdentifier.isEmpty {
                packagesLoadIdentifier += ",search:\(searchBar.text ?? "")"
            } else {
                packagesLoadIdentifier = "search:\(searchBar.text ?? "")"
            }
        }
        let query = searchBar.text ?? ""
        DispatchQueue.global(qos: .default).async {
            self.mutexLock.wait()
            self.updatingCount += 1
            let packageManager = PackageListManager.shared
            var packages: [Package] = []
            if let cachedPackages = self.searchCache[query] {
                packages = cachedPackages
            } else {
                packages = packageManager.packagesList(loadIdentifier: packagesLoadIdentifier, repoContext: self.repoContext, sortPackages: true,
                                                       lookupTable: self.searchCache ) ?? [Package]()
                
            }
            self.mutexLock.signal()
            self.mutexLock.wait()
            if packagesLoadIdentifier == "--installed" && UserDefaults.standard.bool(forKey: "sortInstalledByDate") {
                packages = packages.sorted(by: { package1, package2 -> Bool in
                    let packageURL1 = PackageListManager.shared.dpkgDir.appendingPathComponent("info/\(package1.package).list")
                    let packageURL2 = PackageListManager.shared.dpkgDir.appendingPathComponent("info/\(package2.package).list")
                    let attributes1 = try? FileManager.default.attributesOfItem(atPath: packageURL1.path)
                    let attributes2 = try? FileManager.default.attributesOfItem(atPath: packageURL2.path)
                    if let date1 = attributes1?[FileAttributeKey.modificationDate] as? Date,
                        let date2 = attributes2?[FileAttributeKey.modificationDate] as? Date {
                        return date2.compare(date1) == .orderedAscending
                    }
                    return true
                })
            }
            self.packages = packages
            self.updatingCount -= 1
            self.mutexLock.signal()
            DispatchQueue.main.async {
                self.updateProvisional()
                self.mutexLock.wait()
                if self.updatingCount == 0 && self.refreshEnabled {
                    UIView.performWithoutAnimation {
                        if self.showUpdates {
                            self.collectionView?.reloadSections(IndexSet(integer: 1))
                        } else {
                            self.collectionView?.reloadData()
                        }
                    }
                }
                self.mutexLock.signal()
            }
        }
    }
}
