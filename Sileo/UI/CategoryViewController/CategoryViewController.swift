//
//  CategoryViewController.swift
//  Sileo
//
//  Created by CoolStar on 7/31/19.
//  Copyright © 2019 Sileo Team. All rights reserved.
//

import Foundation
import Evander

class CategoryViewController: SileoTableViewController {
    public var repoContext: Repo?
    
    private var categories: [String]?
    private var categoriesCountCache: [String: Int]?
    
    private var bannersView: FeaturedBannersView?
    private var showInstalled = false
    
    private var headerStackView: UIStackView?
    private var authenticationBannerView: PaymentAuthenticationBannerView?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.navigationItem.largeTitleDisplayMode = .never

        self.tableView.backgroundColor = .sileoBackgroundColor
        self.tableView.separatorColor = .sileoSeparatorColor
        
        weak var weakSelf = self
        NotificationCenter.default.addObserver(weakSelf as Any,
                                               selector: #selector(updateSileoColors),
                                               name: SileoThemeManager.sileoChangedThemeNotification,
                                               object: nil)
        
        self.reloadData()
        
        let headerStackView = UIStackView()
        headerStackView.translatesAutoresizingMaskIntoConstraints = false
        headerStackView.axis = .vertical
        self.tableView.tableHeaderView = headerStackView
        
        headerStackView.topAnchor.constraint(equalTo: self.tableView.topAnchor).isActive = true
        headerStackView.centerXAnchor.constraint(equalTo: self.tableView.centerXAnchor).isActive = true
        headerStackView.widthAnchor.constraint(equalTo: self.tableView.widthAnchor).isActive = true
        
        self.headerStackView = headerStackView
        
        NotificationCenter.default.addObserver([self],
                                               selector: #selector(CategoryViewController.reloadData),
                                               name: PackageListManager.reloadNotification,
                                               object: nil)
        
        self.registerForPreviewing(with: self, sourceView: self.tableView)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        updateSileoColors()
    }
    
    @objc func updateSileoColors() {
        self.tableView.separatorColor = .sileoSeparatorColor
        self.tableView.backgroundColor = .sileoBackgroundColor
        self.statusBarStyle = .default
    }
    
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        updateSileoColors()
    }
    
    @objc func reloadData() {
        DispatchQueue.global(qos: .userInteractive).async {
            var categories: Set<String> = []
            var categoriesCountCache: [String: Int] = [:]
            let packages: [Package]?
            let installed: [Package]?
            if let context = self.repoContext,
                  let url = context.url {
                let betterContext = RepoManager.shared.repo(with: url) ?? context
                packages =  betterContext.packageArray
                installed = betterContext.installed
            } else {
                packages = PackageListManager.shared.allPackagesArray
                installed = nil
            }
            
            for package in packages ?? [] {
                let category = PackageListManager.humanReadableCategory(package.section)
                if !categories.contains(category) {
                    categories.insert(category)
                }
                let loadIdentifier = "category:\(category)"
                let count = categoriesCountCache[loadIdentifier] ?? 0
                categoriesCountCache[loadIdentifier] = count + 1
            }
            categoriesCountCache["--allCategories"] = packages?.count ?? 0
            categoriesCountCache["--contextInstalled"] = installed?.count ?? 0
            self.showInstalled = !(installed?.isEmpty ?? true)
            self.categoriesCountCache = categoriesCountCache
            self.categories = categories.sorted(by: { str1, str2 -> Bool in
                str1.compare(str2) != .orderedDescending
            })
            DispatchQueue.main.async {
                self.tableView.reloadData()
            }
        }
        if let headerStackView = headerStackView {
            for view in headerStackView.arrangedSubviews {
                view.removeFromSuperview()
            }
        }
        if let repoContext = repoContext {
            PaymentManager.shared.getPaymentProvider(for: repoContext) { _, provider in
                self.authenticationBannerView?.removeFromSuperview()
                guard let provider = provider,
                    !provider.isAuthenticated else {
                    return
                }
                provider.fetchInfo(fromCache: true) { _, info in
                    guard let info = info,
                    let banner = info["authentication_banner"] as? [String: String] else {
                        return
                    }
                    DispatchQueue.main.async {
                        self.authenticationBannerView?.removeFromSuperview()
                        let authenticationBannerView = PaymentAuthenticationBannerView(provider: provider,
                                                                                       bannerDictionary: banner,
                                                                                       viewController: self)
                        self.headerStackView?.insertArrangedSubview(authenticationBannerView, at: 0)
                        self.authenticationBannerView = authenticationBannerView
                        self.updateHeaderStackView()
                    }
                }
            }
            
            guard let featuredURL = repoContext.url?.appendingPathComponent("sileo-featured.json") else {
                return
            }
            EvanderNetworking.request(url: featuredURL, type: [String: Any].self, cache: .init(localCache: true, skipNetwork: true)) { [weak self] success, _, _, dict in
                guard success,
                      let `self` = self,
                      let depiction = dict,
                      (depiction["class"] as? String) == "FeaturedBannersView" else { return }
                guard let banners = depiction["banners"] as? [[String: Any]],
                      !banners.isEmpty else { return }
                DispatchQueue.main.async {
                    if let headerView = FeaturedBannersView.view(dictionary: depiction, viewController: self, tintColor: nil, isActionable: false) {
                        let newHeight = headerView.depictionHeight(width: self.view.bounds.width)
                        headerView.heightAnchor.constraint(equalToConstant: newHeight).isActive = true
                        for view in self.headerStackView?.arrangedSubviews ?? [] {
                            view.removeFromSuperview()
                        }
                        self.headerStackView?.addArrangedSubview(headerView)
                        self.updateHeaderStackView()
                    }
                }
            }
        }
    }
    
    func updateHeaderStackView() {
        self.updateHeaderStackView(parentSize: self.view.bounds.size)
    }
    
    func updateHeaderStackView(parentSize: CGSize) {
        guard let headerStackView = self.tableView.tableHeaderView as? UIStackView else {
            return
        }
        if headerStackView.arrangedSubviews.isEmpty {
            headerStackView.frame = CGRect(x: .zero, y: .zero, width: parentSize.width, height: 0)
        } else {
            for subview in headerStackView.arrangedSubviews {
                if let bannerView = subview as? FeaturedBannersView {
                    let newHeight = bannerView.depictionHeight(width: parentSize.width)
                    subview.frame = CGRect(x: subview.frame.minX, y: subview.frame.minY, width: subview.frame.width, height: newHeight)
                }
            }
        }
        self.headerStackView?.layoutIfNeeded()
        self.tableView.tableHeaderView = self.headerStackView
    }
    
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        if self.tableView.tableHeaderView?.isKind(of: FeaturedBannersView.self) ?? false {
            coordinator.animate(alongsideTransition: { _ in
                self.updateHeaderStackView(parentSize: size)
            }, completion: nil)
        }
    }
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        1
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        buffer + (categories?.count ?? 0)
    }
    
    func isAllCategories(indexPath: IndexPath) -> Bool {
        indexPath.row == 0
    }
    
    func isInstalled(indexPath: IndexPath) -> Bool {
        showInstalled && (indexPath.row == 1)
    }
    
    func categoryName(indexPath: IndexPath) -> String {
        if self.isAllCategories(indexPath: indexPath) {
            return String(localizationKey: "All_Categories")
        }
        if self.isInstalled(indexPath: indexPath) {
            return String(localizationKey: "Installed_Packages")
        }
        return categories?[indexPath.row  - buffer] ?? ""
    }
    
    func loadIdentifier(forCategoryAt indexPath: IndexPath) -> String {
        if self.isAllCategories(indexPath: indexPath) {
            return "--allCategories"
        }
        if self.isInstalled(indexPath: indexPath) {
            return "--contextInstalled"
        }
        return "category:\(self.categoryName(indexPath: indexPath))"
    }

    var buffer: Int {
        showInstalled ? 2 : 1
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let identifier = "CategoryViewCellIdentifier"
        let cell = tableView.dequeueReusableCell(withIdentifier: identifier) ?? SileoTableViewCell(style: .value1, reuseIdentifier: identifier)
        
        let categoryName = self.categoryName(indexPath: indexPath)
        let loadIdentifier = self.loadIdentifier(forCategoryAt: indexPath)
        let packageCount = categoriesCountCache?[loadIdentifier]
        
        let weight: UIFont.Weight = (self.isAllCategories(indexPath: indexPath) || self.isInstalled(indexPath: indexPath)) ? .semibold : .regular
        if let textLabel = cell.textLabel {
            textLabel.font = UIFont.systemFont(ofSize: textLabel.font.pointSize, weight: weight)
            textLabel.text = categoryName
        }
        
        if let packageCount = packageCount {
            cell.detailTextLabel?.text = NumberFormatter.localizedString(from: NSNumber(value: packageCount), number: .decimal)
        } else {
            cell.detailTextLabel?.text = String(localizationKey: "Loading")
        }
        cell.accessoryType = .disclosureIndicator
        return cell
    }
    
    override func tableView(_ tableView: UITableView, viewForFooterInSection section: Int) -> UIView? {
        UIView() // do not show extraneous tableview separators
    }
    
    func controller(indexPath: IndexPath) -> PackageListViewController {
        let packageListVC = PackageListViewController(nibName: "PackageListViewController", bundle: nil)
        packageListVC.packagesLoadIdentifier = self.loadIdentifier(forCategoryAt: indexPath)
        packageListVC.repoContext = repoContext
        packageListVC.title = self.categoryName(indexPath: indexPath)
        return packageListVC
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        
        let packageListVC = self.controller(indexPath: indexPath)
        self.navigationController?.pushViewController(packageListVC, animated: true)
    }
}

extension CategoryViewController: UIViewControllerPreviewingDelegate {
    func previewingContext(_ previewingContext: UIViewControllerPreviewing, viewControllerForLocation location: CGPoint) -> UIViewController? {
        if location.y <= self.tableView.tableHeaderView?.bounds.height ?? 0 {
            return nil
        }
        guard let indexPath = self.tableView.indexPathForRow(at: location) else {
            return nil
        }
        let categoryVC = self.controller(indexPath: indexPath)
        return categoryVC
    }
    
    func previewingContext(_ previewingContext: UIViewControllerPreviewing, commit viewControllerToCommit: UIViewController) {
        self.navigationController?.pushViewController(viewControllerToCommit, animated: false)
    }
}

@available (iOS 13, *)
extension CategoryViewController {
    override func tableView(_ tableView: UITableView, contextMenuConfigurationForRowAt indexPath: IndexPath, point: CGPoint) -> UIContextMenuConfiguration? {
        let categoryVC = self.controller(indexPath: indexPath)
        return UIContextMenuConfiguration(identifier: indexPath as NSIndexPath, previewProvider: {
            categoryVC
        }, actionProvider: nil)
    }
    
    override func tableView(_ tableView: UITableView, willPerformPreviewActionForMenuWith configuration: UIContextMenuConfiguration, animator: UIContextMenuInteractionCommitAnimating) {
        if let controller = animator.previewViewController {
            animator.addAnimations {
                self.show(controller, sender: self)
            }
        }
    }
}
