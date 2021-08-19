//
//  PackageListViewController.swift
//  Sileo
//
//  Created by CoolStar on 8/14/19.
//  Copyright © 2019 Sileo Team. All rights reserved.
//

import Foundation
import os

class PackageListViewController: SileoViewController, UIGestureRecognizerDelegate {
    @IBOutlet var collectionView: UICollectionView?
    @IBOutlet var downloadsButton: UIBarButtonItem?
    
    @IBInspectable var showSearchField: Bool = false
    @IBInspectable var showUpdates: Bool = false
    @IBInspectable var showWishlist: Bool = false
    @IBInspectable public var loadProvisional: Bool = false
     
    @IBInspectable public var packagesLoadIdentifier: String = ""
    public var repoContext: Repo?
    private var showProvisional: Bool = false
    
    private var packages: [Package] = []
    private var availableUpdates: [Package] = []
    private var ignoredUpdates: [Package] = []
    private var searchCache: [String: [Package]] = [:]
    private var provisionalPackages: [ProvisionalPackage] = []
    
    private var displaySettings = false
    
    private let mutexLock = DispatchSemaphore(value: 1)
    private var updatingCount = 0
    private var canisterHeartbeat: Timer?
    
    @IBInspectable var localizableTitle: String = ""
    
    var searchController: UISearchController?
    
    @objc func updateSileoColors() {
        self.statusBarStyle = .default
        if let textField = searchController?.searchBar.value(forKey: "searchField") as? UITextField {
            textField.textColor = .sileoLabel
        }
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
        
        if loadProvisional {
            showProvisional = UserDefaults.standard.optionalBool("ShowProvisional", fallback: true)
            _ = NotificationCenter.default.addObserver(forName: Notification.Name("ShowProvisional"), object: nil, queue: nil) { _ in
                self.showProvisional = UserDefaults.standard.optionalBool("ShowProvisional", fallback: true)
                self.collectionView?.reloadData()
            }
        }
        
        if showUpdates {
            _ = NotificationCenter.default.addObserver(forName: Notification.Name("ShowIgnoredUpdates"), object: nil, queue: nil) { _ in
                self.reloadUpdates()
            }
        }

        if showWishlist {
            let exportBtn = UIBarButtonItem(title: String(localizationKey: "Export"), style: .plain, target: self, action: #selector(self.exportButtonClicked(_:)))
            self.navigationItem.leftBarButtonItem = exportBtn
            
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
        if self.showUpdates {
            NotificationCenter.default.addObserver(self, selector: #selector(self.reloadUpdates),
                                                   name: PackageListManager.prefsNotification,
                                                   object: nil)
        }
        if loadProvisional {
            NotificationCenter.default.addObserver(self, selector: #selector(self.reloadData),
                                                   name: CanisterResolver.refreshList,
                                                   object: nil)
        }
        
        // A value of exactly 17.0 (the default) causes the text to auto-shrink
        UITextField.appearance(whenContainedInInstancesOf: [UISearchBar.self]).defaultTextAttributes = [
            NSAttributedString.Key.font: UIFont.systemFont(ofSize: 17.01)
        ]
        
        searchController = UISearchController(searchResultsController: nil)
        searchController?.searchBar.placeholder = String(localizationKey: "Package_Search.Placeholder")
        if #available(iOS 13, *) {
            searchController?.searchBar.searchTextField.semanticContentAttribute = LanguageHelper.shared.isRtl ? .forceRightToLeft : .forceLeftToRight
        } else {
            let textfieldOfSearchBar = searchController?.searchBar.value(forKey: "searchField") as? UITextField
            textfieldOfSearchBar?.semanticContentAttribute = LanguageHelper.shared.isRtl ? .forceRightToLeft : .forceLeftToRight
        }
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
        tapRecognizer.cancelsTouchesInView = false
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
        DispatchQueue.global(qos: .userInteractive).async {
            let packageMan = PackageListManager.shared
            
            if !self.showSearchField {
                let pkgs = packageMan.packageList(identifier: self.packagesLoadIdentifier, sortPackages: true, repoContext: self.repoContext)
                self.packages = pkgs
                self.searchCache[""] = pkgs
                if let controller = self.searchController {
                    DispatchQueue.main.async { self.updateSearchResults(for: controller) }
                }
            }
            if self.showUpdates {
                let updates = packageMan.availableUpdates()
                self.availableUpdates = updates.filter({ $0.1?.wantInfo != .hold }).map({ $0.0 })
                if UserDefaults.standard.optionalBool("ShowIgnoredUpdates", fallback: true) {
                    self.ignoredUpdates = updates.filter({ $0.1?.wantInfo == .hold }).map({ $0.0 })
                }
            }
            
            DispatchQueue.main.async {
                if !self.availableUpdates.isEmpty {
                    self.navigationController?.tabBarItem.badgeValue = String(format: "%ld", self.availableUpdates.count)
                } else {
                    self.navigationController?.tabBarItem.badgeValue = nil
                }
                
                if let searchController = self.searchController {
                    self.updateSearchResults(for: searchController)
                }
            }
        }
    }

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        searchController?.searchBar.isFirstResponder ?? false
    }
    
    func controller(package: Package) -> PackageViewController {
        let packageViewController = PackageViewController(nibName: "PackageViewController", bundle: nil)
        packageViewController.package = package
        return packageViewController
    }
    
    func controller(indexPath: IndexPath) -> PackageViewController? {
        switch findWhatFuckingSectionThisIs(indexPath.section) {
        case .canister:
            let pro = provisionalPackages[indexPath.row]
            guard let package = CanisterResolver.package(pro) else { return nil }
            return controller(package: package)
        case .ignoredUpdates: return controller(package: ignoredUpdates[indexPath.row])
        case .packages, .reallyBoringList: return controller(package: packages[indexPath.row])
        case .updates: return controller(package: availableUpdates[indexPath.row])
        }
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
            DispatchQueue.global(qos: .userInteractive).async {
                let updates = PackageListManager.shared.availableUpdates()
                self.availableUpdates = updates.filter({ $0.1?.wantInfo != .hold }).map({ $0.0 })
                if UserDefaults.standard.optionalBool("ShowIgnoredUpdates", fallback: true) {
                    self.ignoredUpdates = updates.filter({ $0.1?.wantInfo == .hold }).map({ $0.0 })
                } else {
                    self.ignoredUpdates.removeAll()
                }
                DispatchQueue.main.async {
                    if !self.availableUpdates.isEmpty {
                        self.navigationController?.tabBarItem.badgeValue = String(format: "%ld", self.availableUpdates.count)
                        UIApplication.shared.applicationIconBadgeNumber = self.availableUpdates.count
                    } else {
                        self.navigationController?.tabBarItem.badgeValue = nil
                        UIApplication.shared.applicationIconBadgeNumber = 0
                    }
                    if let searchController = self.searchController {
                        self.updateSearchResults(for: searchController)
                    }
                }
            }
        }
    }
    
    @objc func exportButtonClicked(_ button: UIButton?) {
        let alert = UIAlertController(title: String(localizationKey: "Export"), message: String(localizationKey: "Export_Packages"), preferredStyle: .alert)
        
        let defaultAction = UIAlertAction(title: String(localizationKey: "Export_Yes"), style: .default, handler: { _ in
            self.copyPackages()
        })
        alert.addAction(defaultAction)
        
        let cancelAction = UIAlertAction(title: String(localizationKey: "Export_No"), style: .cancel, handler: { _ in
        })
        alert.addAction(cancelAction)
        
        self.present(alert, animated: true)
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
        
        if let subRange = Range<String.Index>(NSRange(location: bodyFromArray.count - 1, length: 1), in: bodyFromArray) {
            bodyFromArray.removeSubrange(subRange)
        }
        
        let pasteboard = UIPasteboard.general
        pasteboard.string = bodyFromArray
    }
    
    enum SortMode {
        case name
        case installdate
        case size
        
        init(from string: String?) {
            switch string {
            case "installdate": self = .installdate
            case "size": self = .size
            default: self = .name
            }
        }
        
        init() {
            self = .init(from: UserDefaults.standard.string(forKey: "InstallSortType"))
        }
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
        let alert = UIAlertController(title: String(localizationKey: "Sort_By"), message: nil, preferredStyle: .actionSheet)
        alert.modalPresentationStyle = .popover
        alert.popoverPresentationController?.sourceView = sender
        
        let nameAction = UIAlertAction(title: String(localizationKey: "Sort_Name"), style: .default, handler: { _ in
            UserDefaults.standard.set("name", forKey: "InstallSortType")
            if let searchController = self.searchController {
                self.updateSearchResults(for: searchController)
            }
            self.dismiss(animated: true, completion: nil)
        })
        alert.addAction(nameAction)
        
        let dateAction = UIAlertAction(title: String(localizationKey: "Sort_Date"), style: .default, handler: { _ in
            UserDefaults.standard.set("installdate", forKey: "InstallSortType")
            if let searchController = self.searchController {
                self.updateSearchResults(for: searchController)
            }
            self.dismiss(animated: true, completion: nil)
        })
        alert.addAction(dateAction)
        
        let sizeAction = UIAlertAction(title: String(localizationKey: "Sort_Install_Size"), style: .default, handler: { _ in
            UserDefaults.standard.set("size", forKey: "InstallSortType")
            if let searchController = self.searchController {
                self.updateSearchResults(for: searchController)
            }
            self.dismiss(animated: true, completion: nil)
        })
        alert.addAction(sizeAction)
        
        let cancelAction = UIAlertAction(title: String(localizationKey: "Cancel"), style: .cancel, handler: { _ in
            self.dismiss(animated: true, completion: nil)
        })
        alert.addAction(cancelAction)
        
        self.present(alert, animated: true, completion: nil)
    }
}

extension PackageListViewController: UICollectionViewDataSource {
    func numberOfSections(in collectionView: UICollectionView) -> Int {
        var count = 0
        if !packages.isEmpty { count += 1 }
        if showUpdates {
            if !availableUpdates.isEmpty { count += 1 }
            if !ignoredUpdates.isEmpty { count += 1 }
        }
        if showProvisional && loadProvisional {
            if !provisionalPackages.isEmpty { count += 1 }
        }
        return count
    }
    
    private func findWhatFuckingSectionThisIs(_ section: Int) -> PackageListSection {
        if showUpdates {
            if !availableUpdates.isEmpty && section == 0 {
                return .updates
            } else if availableUpdates.isEmpty && !ignoredUpdates.isEmpty && section == 0 {
                return .ignoredUpdates
            } else if section == 1 && !availableUpdates.isEmpty && !ignoredUpdates.isEmpty {
                return .ignoredUpdates
            }
            return .packages
        }
        if loadProvisional {
            if !showProvisional { return .reallyBoringList }
            if section == 1 {
                return .canister
            } else if section == 0 && !packages.isEmpty {
                return .packages
            } else if section == 0 && packages.isEmpty {
                return .canister
            }
        }
        return .reallyBoringList
    }
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        switch findWhatFuckingSectionThisIs(section) {
        case .canister: return provisionalPackages.count
        case .ignoredUpdates: return ignoredUpdates.count
        case .packages, .reallyBoringList: return packages.count
        case .updates: return availableUpdates.count
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cellIdentifier = "PackageListViewCellIdentifier"
        guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: cellIdentifier, for: indexPath) as? PackageCollectionViewCell else {
            fatalError("This is what we call a pro gamer move, where we fatalError because of something horrendous")
        }
        switch findWhatFuckingSectionThisIs(indexPath.section) {
        case .canister: cell.provisionalTarget = provisionalPackages[safe: indexPath.row]; cell.targetPackage = nil
        case .ignoredUpdates: cell.targetPackage = ignoredUpdates[safe: indexPath.row]; cell.provisionalTarget = nil
        case .packages, .reallyBoringList: cell.targetPackage = packages[safe: indexPath.row]; cell.provisionalTarget = nil
        case .updates: cell.targetPackage = availableUpdates[safe: indexPath.row]; cell.provisionalTarget = nil
        }
        return cell
    }
    
    func collectionView(_ collectionView: UICollectionView, viewForSupplementaryElementOfKind kind: String, at indexPath: IndexPath) -> UICollectionReusableView {
        let section = findWhatFuckingSectionThisIs(indexPath.section)
        if section == .reallyBoringList {
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
        switch findWhatFuckingSectionThisIs(indexPath.section) {
        case .canister:
            headerView.actionText = nil
            headerView.separatorView?.isHidden = false
            headerView.sortContainer?.isHidden = true
            headerView.upgradeButton?.isHidden = true
            headerView.label?.text = String(localizationKey: "External_Repo")
            return headerView
        case .ignoredUpdates:
            headerView.actionText = nil
            headerView.separatorView?.isHidden = false
            headerView.sortContainer?.isHidden = true
            headerView.upgradeButton?.isHidden = true
            headerView.label?.text = String(localizationKey: "Ignored Updates")
            return headerView
        case .updates:
            headerView.label?.text = String(localizationKey: "Updates_Heading")
            headerView.actionText = String(localizationKey: "Upgrade_All_Button")
            headerView.sortContainer?.isHidden = true
            headerView.separatorView?.isHidden = true
            headerView.upgradeButton?.addTarget(self, action: #selector(self.upgradeAllClicked(_:)), for: .touchUpInside)
            return headerView
        case .packages:
            if showUpdates {
                headerView.label?.text = String(localizationKey: "Installed_Heading")
                headerView.actionText = nil
                headerView.sortContainer?.isHidden = false
                switch SortMode() {
                case .name: headerView.sortHeader?.text = String(localizationKey: "Sort_Name")
                case .installdate: headerView.sortHeader?.text = String(localizationKey: "Sort_Date")
                case .size: headerView.sortHeader?.text = String(localizationKey: "Sort_Install_Size")
                }
                headerView.sortContainer?.addTarget(self, action: #selector(self.sortPopup(sender:)), for: .touchUpInside)
                headerView.separatorView?.isHidden = false
                return headerView
            } else if showProvisional && loadProvisional {
                headerView.actionText = nil
                headerView.separatorView?.isHidden = false
                headerView.sortContainer?.isHidden = true
                headerView.upgradeButton?.isHidden = true
                headerView.label?.text = String(localizationKey: "Internal_Repo")
                return headerView
            }
        case .reallyBoringList: fatalError("Literally impossible to be here")
        }
        return UICollectionReusableView()
    }
}

extension PackageListViewController: UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        collectionView.deselectItem(at: indexPath, animated: true)
        guard let pvc = self.controller(indexPath: indexPath) else { return }
        self.navigationController?.pushViewController(pvc, animated: true)
    }
}

extension PackageListViewController: UICollectionViewDelegateFlowLayout {
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, referenceSizeForHeaderInSection section: Int) -> CGSize {
        switch findWhatFuckingSectionThisIs(section) {
        case .reallyBoringList: return .zero
        case .ignoredUpdates, .updates, .canister: return CGSize(width: collectionView.bounds.width, height: 65)
        case .packages:
            return (showUpdates && displaySettings) ? CGSize(width: collectionView.bounds.width, height: 109) : CGSize(width: collectionView.bounds.width, height: 65)
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
        guard let indexPath = collectionView?.indexPathForItem(at: location),
              let pvc = self.controller(indexPath: indexPath)
        else {
            return nil
        }
        return pvc
    }
    
    func previewingContext(_ previewingContext: UIViewControllerPreviewing, commit viewControllerToCommit: UIViewController) {
        self.navigationController?.pushViewController(viewControllerToCommit, animated: true)
    }
}

@available(iOS 13.0, *)
extension PackageListViewController {
    func collectionView(_ collectionView: UICollectionView, contextMenuConfigurationForItemAt indexPath: IndexPath, point: CGPoint) -> UIContextMenuConfiguration? {
        guard let pvc = self.controller(indexPath: indexPath) else {
            return nil
        }
        
        let menuItems = pvc.actions()
        let config = UIContextMenuConfiguration(identifier: nil, previewProvider: {
            pvc
        }, actionProvider: { _ in
            UIMenu(title: "", options: .displayInline, children: menuItems)
        })
        
        return config
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
    
    func searchBarCancelButtonClicked(_ searchBar: UISearchBar) {
        self.provisionalPackages.removeAll()
        self.packages.removeAll()
        self.collectionView?.reloadData()
    }
    
    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        guard let text = searchBar.text,
              !text.isEmpty,
              showProvisional,
              loadProvisional
        else {
            return
        }
        CanisterResolver.shared.fetch(text) { change in
            guard change else { return }
            DispatchQueue.main.async {
                self.updateSearchResults(for: self.searchController ?? UISearchController())
            }
        }
    }

    private enum UpdateType {
       case insert
       case delete
       case refresh
       case nothing
   }
   
   @discardableResult private func updateProvisional() -> UpdateType {
       if !showProvisional {
           return .nothing
       }
       
       let text = (searchController?.searchBar.text ?? "").lowercased()
       if text.isEmpty {
           let isEmpty = provisionalPackages.isEmpty
           self.provisionalPackages.removeAll()
           return isEmpty ? .nothing : .delete
       }
       
       let all = PackageListManager.shared.allPackagesArray
       let oldEmpty = provisionalPackages.isEmpty
       self.provisionalPackages = CanisterResolver.shared.packages.filter {(package: ProvisionalPackage) -> Bool in
           let search = (package.name?.lowercased().contains(text) ?? false) ||
               (package.identifier?.lowercased().contains(text) ?? false) ||
               (package.description?.lowercased().contains(text) ?? false) ||
               (package.author?.lowercased().contains(text) ?? false)
           if !search {
               return false
           }
           
           let newer = DpkgWrapper.isVersion(package.version ?? "", greaterThan: all.first(where: { $0.packageID == package.identifier })?.version ?? "")
           
           let localRepo = all.contains(where: { package.identifier == $0.packageID })
           if localRepo {
               return newer
           }
           return true
       }
       if oldEmpty && provisionalPackages.isEmpty {
           return .nothing
       } else if !oldEmpty && provisionalPackages.isEmpty {
           return .delete
       } else if oldEmpty && !provisionalPackages.isEmpty {
           return .insert
       } else {
           return .refresh
       }
   }
}

extension PackageListViewController: UISearchResultsUpdating {
    func updateSearchResults(for searchController: UISearchController) {
        
        func handleResponse(_ response: UpdateType) {
            switch response {
            case .nothing: return
            case .refresh: collectionView?.reloadSections(IndexSet(integer: packages.isEmpty ? 0 : 1))
            case .delete: collectionView?.deleteSections(IndexSet(integer: packages.isEmpty ? 0 : 1))
            case .insert: collectionView?.insertSections(IndexSet(integer: packages.isEmpty ? 0 : 1))
            }
        }
        
        let searchBar = searchController.searchBar
        self.canisterHeartbeat?.invalidate()
    
        if searchBar.text?.isEmpty ?? true {
            self.searchCache = [:]
            if showSearchField {
                packages = []
                provisionalPackages = []
            }
        } else {
            canisterHeartbeat = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: false) { [weak self] _ in
                CanisterResolver.shared.fetch(searchBar.text ?? "") { change in
                    guard change else { return }
                    DispatchQueue.main.async {
                        let response = self?.updateProvisional() ?? .nothing
                        handleResponse(response)
                    }
                }
            }
        }
        
        let query = searchBar.text ?? ""
        if query.isEmpty && packagesLoadIdentifier.isEmpty && repoContext == nil {
            collectionView?.reloadData()
            return
        }
        DispatchQueue.global(qos: .userInteractive).async {
            self.mutexLock.wait()
            self.updatingCount += 1
            
            let packageManager = PackageListManager.shared
            var packages: [Package] = []
            
            if self.packagesLoadIdentifier == "--contextInstalled" {
                guard let context = self.repoContext,
                      let url = context.url else { return }
                let betterContext = RepoManager.shared.repo(with: url) ?? context
                packages = packageManager.packageList(identifier: self.packagesLoadIdentifier,
                                                      search: query,
                                                      sortPackages: true,
                                                      repoContext: nil,
                                                      lookupTable: self.searchCache,
                                                      packagePrepend: betterContext.installed ?? [])
            } else if let cachedPackages = self.searchCache[query] {
                packages = cachedPackages
            } else {
                packages = packageManager.packageList(identifier: self.packagesLoadIdentifier,
                                                      search: query,
                                                      sortPackages: self.packagesLoadIdentifier == "--installed" ? false : true,
                                                      repoContext: self.repoContext,
                                                      lookupTable: self.searchCache)
            }
            
            if self.packagesLoadIdentifier == "--installed" {
                var allPackages: [String: Package] = [:]
                _ = packages.map { allPackages[$0.packageID] = $0 }
                let foundPackages = packageManager.packages(identifiers: Array(allPackages.keys), sorted: false)
                for package in foundPackages {
                    guard let existing = allPackages[package.packageID] else { continue }
                    if existing.version == package.version {
                        allPackages[package.packageID] = package
                    } else {
                        if let correct = package.allVersions.first(where: { $0.version == package.version }) {
                            allPackages[package.packageID] = correct
                        }
                    }
                }
                packages = Array(allPackages.values)
                switch SortMode() {
                case .installdate:
                    packages = packages.sorted(by: { package1, package2 -> Bool in
                        let packageURL1 = CommandPath.dpkgDir.appendingPathComponent("info/\(package1.package).list")
                        let packageURL2 = CommandPath.dpkgDir.appendingPathComponent("info/\(package2.package).list")
                        let attributes1 = try? FileManager.default.attributesOfItem(atPath: packageURL1.path)
                        let attributes2 = try? FileManager.default.attributesOfItem(atPath: packageURL2.path)
                        
                        if let date1 = attributes1?[FileAttributeKey.modificationDate] as? Date,
                            let date2 = attributes2?[FileAttributeKey.modificationDate] as? Date {
                            return date2.compare(date1) == .orderedAscending
                        }
                        
                        return true
                    })
                case .size:
                    packages = packages.sorted { $0.installedSize ?? 0 > $1.installedSize ?? 0 }
                case .name:
                    packages = packageManager.sortPackages(packages: packages, search: query)
                }
            }
            
            self.mutexLock.signal()
            self.mutexLock.wait()
            self.updatingCount -= 1
            self.mutexLock.signal()
            
            DispatchQueue.main.async {
                self.updateProvisional()
                self.mutexLock.wait()
                
                if self.updatingCount == 0 {
                    UIView.performWithoutAnimation {
                        self.packages = packages
                        self.collectionView?.reloadData()
                    }
                }
                
                self.mutexLock.signal()
            }
        }
    }
}

extension Collection {
    subscript (safe index: Index) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}

enum PackageListSection {
    case updates
    case ignoredUpdates
    case packages
    case canister
    case reallyBoringList
}
