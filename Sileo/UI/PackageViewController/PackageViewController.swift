//
//  PackageViewController.swift
//  Sileo
//
//  Created by CoolStar on 8/31/19.
//  Copyright © 2019 Sileo Team. All rights reserved.
//

import Foundation
import SafariServices
import MessageUI
import Evander
import os.log

class PackageViewController: SileoViewController, PackageQueueButtonDataProvider,
    UIScrollViewDelegate, DepictionViewDelegate, MFMailComposeViewControllerDelegate, PackageActions {
    public var package: Package?
    public var depictionHeight = CGFloat(0)

    public var isPresentedModally = false

    private weak var weakNavController: UINavigationController?

    @IBOutlet private var scrollView: UIScrollView!
    @IBOutlet private var contentView: UIView!

    @IBOutlet private var packageName: UILabel!
    @IBOutlet private var packageAuthor: UILabel!

    @IBOutlet private var packageIconView: PackageIconView!

    @IBOutlet private var downloadButton: PackageQueueButton!
    private var navBarDownloadButton: PackageQueueButton?
    private var packageNavBarIconView: PackageIconView?
    private var shareButton: UIButton?

    private var navBarShareButtonItem: UIBarButtonItem?
    private var navBarDownloadButtonItem: UIBarButtonItem?

    private var depictionView: DepictionBaseView?
    private var depictionFooterView: DepictionBaseView?

    private var paymentProvider = ""
    private var price = ""
    private var purchased = false
    private var available = false
    private var headerURL: String?

    private var installedPackage: Package?

    @IBOutlet private var depictionHeaderView: UIView!
    @IBOutlet private var depictionBackgroundShadow: UIImageView!
    @IBOutlet private var depictionBackgroundView: UIImageView!
    @IBOutlet private var packageInfoView: UIStackView!

    @IBOutlet private var depictionHeaderImageViewHeight: NSLayoutConstraint!
    @IBOutlet private var contentViewHeight: NSLayoutConstraint!
    @IBOutlet private var contentViewWidth: NSLayoutConstraint!
    @IBOutlet private var downloadButtonWidth: NSLayoutConstraint!

    private var allowNavbarUpdates = false
    private var currentNavBarOpacity = CGFloat(0)

    private var isUpdatingPurchaseStatus = false
    
    private func parseNativeDepiction(_ data: Data, host: String, failureCallback: (() -> Void)?) {
        guard let rawJSON = try? JSONSerialization.jsonObject(with: data, options: []),
              let rawDepict = rawJSON as? [String: Any]
        else {
            failureCallback?()
            return
        }
        if !Thread.isMainThread {
            DispatchQueue.main.async { [weak self] in
                self?.parseNativeDepiction(data, host: host, failureCallback: failureCallback)
            }
            return
        }
        
        if let rawTintColor = rawDepict["tintColor"] as? String, let tintColor = UIColor(css: rawTintColor) {
            self.depictionFooterView?.tintColor = tintColor
            self.downloadButton.tintColor = tintColor
            self.downloadButton.updateStyle()
            self.navBarDownloadButton?.tintColor = tintColor
            self.navBarDownloadButton?.updateStyle()
        }
        
        let oldDepictView = self.depictionView
        guard let newDepictView = DepictionBaseView.view(dictionary: rawDepict, viewController: self, tintColor: nil, isActionable: false) else {
            return
        }
        
        oldDepictView?.delegate = nil
        newDepictView.delegate = self
        
        if let imageURL = rawDepict["headerImage"] as? String {
            if imageURL != headerURL {
                self.headerURL = imageURL
                self.depictionBackgroundView.image = EvanderNetworking.shared.image(imageURL, size: depictionBackgroundView.frame.size) { [weak self] refresh, image in
                    if refresh,
                       let strong = self,
                       imageURL == strong.headerURL,
                       let image = image {
                        DispatchQueue.main.async {
                            strong.depictionBackgroundView.image = image
                        }
                    }
                }
            }
        }
        
        newDepictView.alpha = 0.1
        self.depictionView = newDepictView
        self.contentView.addSubview(newDepictView)
        self.viewDidLayoutSubviews()
        
        UIView.animate(withDuration: 0.25, animations: {
            oldDepictView?.alpha = 0
            newDepictView.alpha = 1
        }, completion: { _ in
            oldDepictView?.removeFromSuperview()
            if let minVersion = rawDepict["minVersion"] as? String,
                minVersion.compare(StoreVersion) == .orderedDescending {
                self.versionTooLow()
            }
        })
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        
        weakNavController = self.navigationController
        
        weak var weakSelf = self
        NotificationCenter.default.addObserver(weakSelf as Any,
                                               selector: #selector(updateSileoColors),
                                               name: SileoThemeManager.sileoChangedThemeNotification,
                                               object: nil)
        
        packageName.textColor = .sileoLabel
        let collapsed = splitViewController?.isCollapsed ?? false
        let navController = collapsed ? (splitViewController?.viewControllers[0] as? UINavigationController) : self.navigationController
        navController?.setNavigationBarHidden(true, animated: true)

        self.navigationItem.largeTitleDisplayMode = .never
        scrollView.delegate = self
        
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(PackageViewController.reloadData),
                                               name: PackageListManager.reloadNotification,
                                               object: nil)

        packageIconView.layer.cornerRadius = 15

        self.extendedLayoutIncludesOpaqueBars = true
        self.edgesForExtendedLayout = [.top, .bottom]

        scrollView.contentInsetAdjustmentBehavior = .never
        scrollView.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: self.tabBarController?.tabBar.bounds.height ?? 0, right: 0)

        allowNavbarUpdates = true
        depictionHeaderImageViewHeight.constant = 200
        self.navigationController?.navigationBar._backgroundOpacity = 0
        self.navigationController?.navigationBar.tintColor = .white
        self.statusBarStyle = .lightContent
        
        self.navigationController?.navigationBar.isTranslucent = true
        
        
        downloadButton.viewControllerForPresentation = self
        downloadButton.dataProvider = self
        
        let navBarDownloadButton = PackageQueueButton()
        navBarDownloadButton.viewControllerForPresentation = self
        navBarDownloadButton.dataProvider = self
        self.navBarDownloadButton = navBarDownloadButton

        let shareButton = UIButton(type: .custom)
        shareButton.setImage(UIImage(named: "More"), for: .normal)
        shareButton.addTarget(self, action: #selector(PackageViewController.sharePackage), for: .touchUpInside)
        shareButton.accessibilityIgnoresInvertColors = true
        self.shareButton = shareButton

        navBarDownloadButton.alpha = 0

        navBarDownloadButtonItem = UIBarButtonItem(customView: navBarDownloadButton)
        let navBarShareButtonItem = UIBarButtonItem(customView: shareButton)
        self.navBarShareButtonItem = navBarShareButtonItem

        self.navigationItem.rightBarButtonItems = [navBarShareButtonItem]

        let packageNavBarIconViewController = UIView(frame: CGRect(origin: .zero, size: CGSize(width: 50, height: 32)))

        let packageNavBarIconView = PackageIconView(frame: CGRect(origin: .zero, size: CGSize(width: 32, height: 32)))
        packageNavBarIconView.center = packageNavBarIconViewController.center
        packageNavBarIconView.alpha = 0
        packageNavBarIconView.image = UIImage(named: "Tweak Icon")
        self.packageNavBarIconView = packageNavBarIconView

        packageNavBarIconViewController.addSubview(packageNavBarIconView)
        self.navigationItem.titleView = packageNavBarIconViewController

        if self.isPresentedModally {
            self.navigationItem.leftBarButtonItem = UIBarButtonItem(title: String(localizationKey: "Done"),
                                                                    style: .done,
                                                                    target: self,
                                                                    action: #selector(PackageViewController.dismissImmediately))
        }

        self.reloadData()

        self.viewDidLayoutSubviews()
    }

    @objc func updateSileoColors() {
        packageName.textColor = .sileoLabel
    }
    
    @objc func reloadData() {
        guard Thread.current.isMainThread else {
            DispatchQueue.main.async {
                self.reloadData()
            }
            return
        }
        
        depictionView?.removeFromSuperview()
        depictionView = nil

        guard var package = package else {
            return
        }
        
        if package.packageFileURL == nil {
            if let newestPackage = PackageListManager.shared.newestPackage(identifier: package.package, repoContext: nil) {
                package = newestPackage
                self.package = package
            }
        }

        let installedPackage = PackageListManager.shared.installedPackage(identifier: package.package)
        self.installedPackage = installedPackage

        packageName.text = package.name
        packageAuthor.text = ControlFileParser.authorName(string: package.author ?? "")

        downloadButton.package = package
        navBarDownloadButton?.package = package
        
        if let imageURL = package.rawControl["header"] {
            if imageURL != headerURL {
                self.headerURL = imageURL
                self.depictionBackgroundView.image = EvanderNetworking.shared.image(imageURL, size: CGSize(width: depictionBackgroundView.frame.width, height: 200)) { [weak self] refresh, image in
                    if refresh,
                       let strong = self,
                       imageURL == strong.headerURL,
                       let image = image {
                        DispatchQueue.main.async {
                            strong.depictionBackgroundView.image = image
                        }
                    }
                }
            }
        }
        
        if package.hasIcon(),
            let rawIcon = package.icon {
            let image = EvanderNetworking.shared.image(rawIcon, size: packageIconView.frame.size) { [weak self] refresh, image in
                if refresh,
                    let strong = self,
                    let image = image,
                    strong.package?.icon == rawIcon {
                        DispatchQueue.main.async {
                            strong.packageIconView.image = image
                            strong.packageNavBarIconView?.image = image
                        }
                }
            } ?? UIImage(named: "Tweak Icon")
            packageIconView.image = image
            packageNavBarIconView?.image = image
        }

        var rawDescription: [[String: Any]] = [
            [
                "class": "DepictionMarkdownView",
                "markdown": package.packageDescription ?? String(localizationKey: "Package_No_Description_Available"),
                "useSpacing": true
            ]
        ]
        if package.legacyDepiction != nil && package.depiction == nil {
            rawDescription.append([
                "class": "DepictionTableButtonView",
                "title": String(localizationKey: "View_Depiction"),
                "action": package.legacyDepiction ?? ""
            ] as [String: Any])
        }

        let rawDepiction = [
            "class": "DepictionTabView",
            "tabs": [
                [
                    "tabname": String(localizationKey: "Package_Details_Tab"),
                    "class": "DepictionStackView",
                    "views": rawDescription
                ], [
                    "tabname": String(localizationKey: "Package_Changelog_Tab"),
                    "class": "DepictionStackView",
                    "views": [[
                        "class": "DepictionMarkdownView",
                        "markdown": String(localizationKey: "Package_Changelogs_Unavailable"),
                        "useSpacing": true
                    ]]
                ]
            ]
        ] as [String: Any]

        if let depictionView = DepictionBaseView.view(dictionary: rawDepiction, viewController: self, tintColor: nil, isActionable: false) {
            depictionView.delegate = self
            contentView.addSubview(depictionView)
            self.depictionView = depictionView
        }

        if let depiction = package.depiction,
            let depictionURL = URL(string: depiction) {
            let urlRequest = URLManager.urlRequest(depictionURL)
            EvanderNetworking.request(request: urlRequest, type: Data.self) { [weak self] success, _, _, data in
                guard success,
                      let data = data,
                      let `self` = self else { return }
                self.parseNativeDepiction(data, host: depictionURL.host ?? "", failureCallback: nil)
            }
        }

        depictionFooterView?.removeFromSuperview()
        var footerDict: [String: Any] = [
            "class": "DepictionStackView"
        ]
        var views = [[String: Any]]()
        if installedPackage != nil {
            views = [
                [
                    "class": "DepictionSeparatorView"
                ],
                [
                    "class": "DepictionHeaderView",
                    "title": String(localizationKey: "Installed_Package_Header")
                ],
                [
                    "class": "DepictionTableTextView",
                    "title": String(localizationKey: "Version"),
                    "text": installedPackage?.version ?? ""
                ],
                [
                    "class": "DepictionTableButtonView",
                    "title": String(localizationKey: "Show_Package_Contents_Button"),
                    "action": "showInstalledContents"
                ],
                [
                    "class": "DepictionSeparatorView"
                ]
            ]
        }
        if let repo = package.sourceRepo {
            views.insert([
                "class": "DepictionSeparatorView"
            ], at: 0)
            views.insert([
                "class": "DepictionHeaderView",
                "title": String(localizationKey: "Repo")
            ], at: 1)
            views.insert([
                "class": "DepictionTableButtonView",
                "title": repo.displayName,
                "action": "showRepoContext",
                "_repo": repo.url?.absoluteString as Any
            ], at: 2)
        }
        views.append([
            "class": "DepictionSubheaderView",
            "alignment": 1,
            "title": "\(package.package) (\(package.version))"
        ])
        footerDict = [
            "class": "DepictionStackView",
            "views": views
        ] as [String: Any]

        if let depictionFooterView = DepictionBaseView.view(dictionary: footerDict, viewController: self, tintColor: nil, isActionable: false) {
            depictionFooterView.delegate = self
            self.depictionFooterView = depictionFooterView
            contentView.addSubview(depictionFooterView)
        }
    }

    func versionTooLow() {
        let alertController = UIAlertController(title: String(localizationKey: "Sileo_Update_Required.Title", type: .error),
                                                message: String(localizationKey: "Featured_Requires_Sileo_Update", type: .error),
                                                preferredStyle: .alert)
        alertController.addAction(UIAlertAction(title: String(localizationKey: "OK"), style: .cancel, handler: { _ in
            self.dismiss(animated: true, completion: nil)
        }))
        self.present(alertController, animated: true, completion: nil)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        self.statusBarStyle = .default
        
        self.navigationController?.navigationBar._backgroundOpacity = currentNavBarOpacity
        self.navigationController?.navigationBar.tintColor = .white
        allowNavbarUpdates = true
        self.scrollViewDidScroll(self.scrollView)
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        let collapsed = splitViewController?.isCollapsed ?? false
        let navController = collapsed ? (splitViewController?.viewControllers[0] as? UINavigationController) : weakNavController
        
        allowNavbarUpdates = false
        currentNavBarOpacity = navController?.navigationBar._backgroundOpacity ?? 1
        
        UIView.animate(withDuration: 0.8) {
            navController?.navigationBar.tintColor = UINavigationBar.appearance().tintColor
            navController?.navigationBar._backgroundOpacity = 1
        }
    }

    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        // do header view scaling magic
        let headerBounds = depictionHeaderView.bounds
        var aspectRatio = headerBounds.width / headerBounds.height
        if headerBounds.height == 0 {
            aspectRatio = 0
        }

        var offset = scrollView.contentOffset.y
        if offset > 0 {
            offset = 0
        }

        var headerBackgroundFrame = CGRect.zero
        headerBackgroundFrame.size.height = headerBounds.height - offset
        headerBackgroundFrame.size.width = headerBackgroundFrame.height * aspectRatio
        headerBackgroundFrame.origin.x = (headerBounds.width - headerBackgroundFrame.width)/2
        headerBackgroundFrame.origin.y = headerBounds.height - headerBackgroundFrame.height

        depictionBackgroundView.frame = headerBackgroundFrame
        depictionBackgroundShadow.frame = headerBackgroundFrame

        // doing the magic on the nav bar "GET" button and package icon
        let downloadButtonPos = downloadButton.convert(downloadButton.bounds, to: scrollView)
        let container = CGRect(origin: CGPoint(x: scrollView.contentOffset.x,
                                               y: scrollView.contentOffset.y + 106 - UIApplication.shared.statusBarFrame.height),
                               size: scrollView.frame.size)
        // TLDR: magic starts when scrolling out the lower half of the button so we don't have duplicated button too early
        var navBarAlphaOffset = scrollView.contentOffset.y * 1.75 / depictionHeaderImageViewHeight.constant
        if depictionHeaderImageViewHeight.constant == 0 {
            navBarAlphaOffset = 0
        }

        if navBarAlphaOffset > 1 {
            navBarAlphaOffset = 1
        } else if navBarAlphaOffset < 0 {
            navBarAlphaOffset = 0
        }

        UIView.animate(withDuration: 0.3) {
            self.shareButton?.alpha = 1 - navBarAlphaOffset

            if (self.shareButton?.alpha ?? 0) > 0 {
                self.packageNavBarIconView?.alpha = 0
            } else {
                self.packageNavBarIconView?.alpha = downloadButtonPos.intersects(container) ? 0 : 1
            }
            self.navBarDownloadButton?.customAlpha = self.packageNavBarIconView?.alpha ?? 0

            if let navBarDownloadButtonItem = self.navBarDownloadButtonItem,
                let navBarShareButtonItem = self.navBarShareButtonItem {
                if (self.shareButton?.alpha ?? 0) > 0 {
                    self.navigationItem.rightBarButtonItems = [navBarShareButtonItem]
                } else {
                    self.navigationItem.rightBarButtonItems = [navBarDownloadButtonItem]
                }
            }
        }

        scrollView.scrollIndicatorInsets.top = max(headerBounds.maxY - scrollView.contentOffset.y, self.view.safeAreaInsets.top)

        guard allowNavbarUpdates else {
            return
        }
        
        let collapsed = splitViewController?.isCollapsed ?? false
        let navController = collapsed ? (splitViewController?.viewControllers[0] as? UINavigationController) : self.navigationController
        navController?.setNavigationBarHidden(false, animated: true)
        if navBarAlphaOffset < 1 {
            var tintColor = UINavigationBar.appearance().tintColor
            if let color = self.depictionView?.tintColor {
                tintColor = color
            }
            var red: CGFloat = 0
            var green: CGFloat = 0
            var blue: CGFloat = 0
            tintColor?.getRed(&red, green: &green, blue: &blue, alpha: nil)

            if UIAccessibility.isInvertColorsEnabled {
                red -= red * (1.0 - navBarAlphaOffset)
                green -= green * (1.0 - navBarAlphaOffset)
                blue -= blue * (1.0 - navBarAlphaOffset)
            } else {
                red += (1.0 - red) * (1.0 - navBarAlphaOffset)
                green += (1.0 - green) * (1.0 - navBarAlphaOffset)
                blue += (1.0 - blue) * (1.0 - navBarAlphaOffset)
            }
            tintColor = UIColor(red: red, green: green, blue: blue, alpha: 1)

            navController?.navigationBar.tintColor = tintColor
            navController?.navigationBar._backgroundOpacity = navBarAlphaOffset
            if navBarAlphaOffset < 0.75 {
                self.statusBarStyle = .lightContent
            } else {
                self.statusBarStyle = .default
            }
        } else {
            navController?.navigationBar.tintColor = UINavigationBar.appearance().tintColor
            if let tintColor = self.depictionView?.tintColor {
                navController?.navigationBar.tintColor = tintColor
            }
            navController?.navigationBar._backgroundOpacity = 1
            self.statusBarStyle = .default
        }
        self.setNeedsStatusBarAppearanceUpdate()
    }

    func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        // for those wondering about the magic numbers and what's going on here:
        // This is the spring effect on scrolling (aka step to start or step to after header
        // 113 = header imageView height - nav bar height and 56 is simply for setitng the step boundary, aka halfway
        // if you don't like this, we can implement the variables from above, instead, but imo it's a waste of time
        let scrollViewOffset = scrollView.contentOffset.y + UIApplication.shared.statusBarFrame.height
        
        if scrollViewOffset < 66 {
            scrollView.setContentOffset(.zero, animated: true)
        } else if scrollViewOffset > 66 && scrollViewOffset < 133 {
            scrollView.setContentOffset(CGPoint(x: 0, y: 156 - UIApplication.shared.statusBarFrame.height), animated: true)
        }
    }

    func subviewHeightChanged() {
        self.viewDidLayoutSubviews()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()

        depictionHeight = depictionView?.depictionHeight(width: self.view.bounds.width) ?? 0

        let headerHeight = packageInfoView.frame.maxY

        depictionView?.frame = CGRect(x: 0, y: headerHeight, width: self.view.bounds.width, height: depictionHeight)

        let footerHeight = depictionFooterView?.depictionHeight(width: self.view.bounds.width) ?? 0
        depictionFooterView?.frame = CGRect(x: 0, y: headerHeight + depictionHeight, width: self.view.bounds.width, height: footerHeight)

        contentView.frame = CGRect(origin: .zero, size: CGSize(width: self.view.bounds.width, height: headerHeight + depictionHeight + footerHeight))
        scrollView.contentSize = CGSize(width: self.view.bounds.width, height: headerHeight + depictionHeight + footerHeight)

        contentViewWidth.constant = scrollView.bounds.width
        contentViewHeight.constant = headerHeight + depictionHeight + footerHeight

        self.view.updateConstraintsIfNeeded()

        scrollView.contentSize = CGSize(width: scrollView.contentSize.width, height: contentViewHeight.constant)
        DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(200)) {
            self.scrollViewDidScroll(self.scrollView)
        }
    }

    @objc func sharePackage(_ sender: Any?) {
        guard let package = self.package,
            let shareButton = self.shareButton else {
            return
        }
        
        let sharePopup = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
        let shareAction = UIAlertAction(title: String(localizationKey: "Package_Share_Action"), style: .default) { _ in
            var packageString = "\(package.name ?? package.package) - \(URLManager.url(package: package.package))"
            if let repo = package.sourceRepo {
                packageString += " - from \(repo.url?.absoluteString ?? repo.rawURL)"
            }
            let activityViewController = UIActivityViewController(activityItems: [packageString], applicationActivities: nil)
            activityViewController.popoverPresentationController?.sourceView = shareButton
            self.present(activityViewController, animated: true, completion: nil)
        }
        sharePopup.addAction(shareAction)
        
        if let author = package.author,
            let email = ControlFileParser.authorEmail(string: author) {
            let moreByDeveloper = UIAlertAction(title: String(localizationKey: "Package_Developer_Find_Action"
            ), style: .default) { _ in
                let packagesListController = PackageListViewController(nibName: "PackageListViewController", bundle: nil)
                packagesListController.packagesLoadIdentifier = "author:\(email)"
                packagesListController.title = String(format: String(localizationKey: "Packages_By_Author"),
                                                      ControlFileParser.authorName(string: author))
                self.navigationController?.pushViewController(packagesListController, animated: true)
            }
            sharePopup.addAction(moreByDeveloper)
        
            let packageSupport = UIAlertAction(title: String(localizationKey: "Package_Support_Action"), style: .default) { _ in
                if !MFMailComposeViewController.canSendMail() {
                    let alertController = UIAlertController(title: String(localizationKey: "Email_Unavailable.Title", type: .error),
                                                            message: String(localizationKey: "Email_Unavailable.Body", type: .error),
                                                            preferredStyle: .alert)
                    alertController.addAction(UIAlertAction(title: String(localizationKey: "OK"), style: .cancel, handler: nil))
                    self.present(alertController, animated: true, completion: nil)
                } else {
                    let composeVC = MFMailComposeViewController()
                    composeVC.setToRecipients([email])
                    composeVC.setSubject("Sileo/APT(M): \(String(describing: package.name))")
                    composeVC.setMessageBody("", isHTML: false)
                    composeVC.mailComposeDelegate = self
                    self.present(composeVC, animated: true, completion: nil)
                }
            }
            sharePopup.addAction(packageSupport)
        }
        
        if installedPackage != nil,
            let packageID = self.package?.package {
            let ignoreUpdatesText = installedPackage?.wantInfo == .hold ?
                String(localizationKey: "Package_Hold_Disable_Action") : String(localizationKey: "Package_Hold_Enable_Action")
            let ignoreUpdates = UIAlertAction(title: ignoreUpdatesText, style: .default) { _ in
                if self.installedPackage?.wantInfo == .hold {
                    self.installedPackage?.wantInfo = .install
                    #if !targetEnvironment(simulator) && !TARGET_SIMULATOR
                    DpkgWrapper.ignoreUpdates(false, package: packageID)
                    #endif
                } else {
                    self.installedPackage?.wantInfo = .hold
                    #if !targetEnvironment(simulator) && !TARGET_SIMULATOR
                    DpkgWrapper.ignoreUpdates(true, package: packageID)
                    #endif
                }
                NotificationCenter.default.post(Notification(name: PackageListManager.prefsNotification))
            }
            sharePopup.addAction(ignoreUpdates)
        }
        
        let wishListText = WishListManager.shared.isPackageInWishList(package.package) ?
            String(localizationKey: "Package_Wishlist_Remove") : String(localizationKey: "Package_Wishlist_Add")
        let wishlist = UIAlertAction(title: wishListText, style: .default) { _ in
            if WishListManager.shared.isPackageInWishList(package.package) {
                WishListManager.shared.removePackageFromWishList(package.package)
            } else {
                _ = WishListManager.shared.addPackageToWishList(package.package)
            }
        }
        sharePopup.addAction(wishlist)
        
        let cancelAction = UIAlertAction(title: String(localizationKey: "Cancel"), style: .cancel, handler: nil)
        sharePopup.addAction(cancelAction)
        
        if UIDevice.current.userInterfaceIdiom == .pad {
            sharePopup.popoverPresentationController?.sourceView = shareButton
        }
        if let tintColor = depictionView?.tintColor {
            sharePopup.view.tintColor = tintColor
        }
        self.present(sharePopup, animated: true)
    }

    func mailComposeController(_ controller: MFMailComposeViewController, didFinishWith result: MFMailComposeResult, error: Error?) {
        // Check the result or perform other tasks.

        // Dismiss the mail compose view controller.
        self.dismiss(animated: true, completion: nil)
    }

    @objc func dismissImmediately() {
        // Dismiss this view controller.
        self.dismiss(animated: true, completion: nil)
    }

    func updatePurchaseStatus() {
        if isUpdatingPurchaseStatus {
            return
        }
        guard let package = self.package,
            let sourceRepo = package.sourceRepo else {
            return
        }
        isUpdatingPurchaseStatus = true

        PaymentManager.shared.getPaymentProvider(for: sourceRepo) { error, provider in
            if error != nil {
                return
            }
            provider?.getPackageInfo(forIdentifier: package.package) { error, info in
                guard let info = info,
                    error == nil else {
                    return
                }
                DispatchQueue.main.async {
                    self.isUpdatingPurchaseStatus = false
                    self.downloadButton.paymentInfo = info
                    self.navBarDownloadButton?.paymentInfo = info
                }
            }
        }
    }
    
    override var previewActionItems: [UIPreviewActionItem] {
        downloadButton.actionItems().map({ $0.previewAction() })
    }
    
    @available (iOS 13.0, *)
    func actions() -> [UIAction] {
        _ = self.view
        return downloadButton.actionItems().map({ $0.action() })
    }
}
