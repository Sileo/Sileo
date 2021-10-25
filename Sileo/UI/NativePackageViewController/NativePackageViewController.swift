//
//  NativePackageViewController.swift
//  Sileo
//
//  Created by Andromeda on 31/08/2021.
//  Copyright © 2021 Sileo Team. All rights reserved.
//

import UIKit
import DepictionKit
import MessageUI
import Evander
import SafariServices

protocol PackageActions: UIViewController {
    @available (iOS 13.0, *)
    func actions() -> [UIAction]
}

class NativePackageViewController: SileoViewController, PackageActions {
    
    public var package: Package
    public var installedPackage: Package?
    private var depictionLink: URL?
    private var depictionHeader: URL?
    
    private var allowNavbarUpdates = false
    private var isUpdatingPurchaseStatus = false
    private var currentNavBarOpacity = CGFloat(0)
    
    public lazy var downloadButton: PackageQueueButton = {
        let button = PackageQueueButton()
        button.translatesAutoresizingMaskIntoConstraints = false
        button.dataProvider = self
        button.viewControllerForPresentation = self
        button.setContentHuggingPriority(UILayoutPriority(252), for: .horizontal)
        button.setContentCompressionResistancePriority(UILayoutPriority(752), for: .horizontal)
        
        return button
    }()
    public var packageIconView: PackageIconView = {
        let view = PackageIconView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.layer.masksToBounds = true
        view.layer.cornerRadius = 15
        return view
    }()
    public var packageNameLabel: UILabel = {
        let view = UILabel()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.font = UIFont.systemFont(ofSize: 20, weight: .semibold)
        view.numberOfLines = 2
        return view
    }()
    public var authorLabel: UILabel = {
        let view = UILabel()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.font = UIFont.systemFont(ofSize: 16)
        view.numberOfLines = 1
        view.textColor = UIColor(red: 0.561, green: 0.557, blue: 0.58, alpha: 1)
        return view
    }()
    public lazy var packageContainer: UIView = {
        let view = UIView()
        view.backgroundColor = .clear
        view.translatesAutoresizingMaskIntoConstraints = false
        view.heightAnchor.constraint(equalToConstant: 120).isActive = true
        
        let labelContainer = UIStackView()
        labelContainer.translatesAutoresizingMaskIntoConstraints = false
        labelContainer.alignment = .fill
        labelContainer.distribution = .fill
        labelContainer.axis = .vertical
        labelContainer.spacing = 4
        labelContainer.addArrangedSubview(packageNameLabel)
        labelContainer.addArrangedSubview(authorLabel)
        
        view.addSubview(packageIconView)
        view.addSubview(labelContainer)
        view.addSubview(downloadButton)
        
        NSLayoutConstraint.activate([
            packageIconView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 15),
            packageIconView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            packageIconView.heightAnchor.constraint(equalToConstant: 60),
            packageIconView.widthAnchor.constraint(equalToConstant: 60),
            
            labelContainer.leadingAnchor.constraint(equalTo: packageIconView.trailingAnchor, constant: 10),
            labelContainer.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            labelContainer.heightAnchor.constraint(equalToConstant: 45),
            
            downloadButton.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            downloadButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -15),
            downloadButton.leadingAnchor.constraint(equalTo: labelContainer.trailingAnchor, constant: -10)
        ])
        return view
    }()
    
    public lazy var depiction: DepictionContainer = {
        DepictionContainer(presentationController: self, theme: theme, delegate: self)
    }()

    public lazy var headerImageViewTopAnchor = contentView.topAnchor.constraint(equalTo: headerImageView.topAnchor)
    public lazy var headerImageViewLeadingAnchor = contentView.leadingAnchor.constraint(equalTo: headerImageView.leadingAnchor)
    public lazy var headerImageViewTrailingAnchor = contentView.trailingAnchor.constraint(equalTo: headerImageView.trailingAnchor)
    public lazy var headerImageViewHeightAnchor = headerImageView.heightAnchor.constraint(equalToConstant: 200)
    public var headerImageView: UIImageView = {
        let view = UIImageView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.contentMode = .scaleAspectFill
        return view
    }()
    
    public lazy var scrollView: UIScrollView = {
        let view = UIScrollView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.backgroundColor = .clear
        view.delegate = self
        return view
    }()
    public var contentView: UIView = {
        let view = UIView()
        view.backgroundColor = .clear
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private lazy var shareButton: UIButton = {
        let shareButton = UIButton(type: .custom)
        shareButton.setImage(UIImage(named: "More"), for: .normal)
        shareButton.addTarget(self, action: #selector(sharePackage), for: .touchUpInside)
        shareButton.accessibilityIgnoresInvertColors = true
        return shareButton
    }()
    private lazy var navBarShareButtonItem = UIBarButtonItem(customView: shareButton)
    
    private var packageNavBarIconView = PackageIconView(frame: CGRect(origin: .zero, size: CGSize(width: 32, height: 32)))
    private lazy var packageNavBarIconViewController: UIView = {
        let view = UIView(frame: CGRect(origin: .zero, size: CGSize(width: 50, height: 32)))
        view.addSubview(packageNavBarIconView)
        packageNavBarIconView.center = view.center
        packageNavBarIconView.alpha = 0
        return view
    }()
    
    private lazy var navBarDownloadButton: PackageQueueButton = {
        let view = PackageQueueButton()
        view.viewControllerForPresentation = self
        view.dataProvider = self
        return view
    }()
    private lazy var navBarDownloadButtonItem = UIBarButtonItem(customView: navBarDownloadButton)
    
    public var theme: Theme {
        Theme(text_color: .sileoLabel,
              background_color: .sileoBackgroundColor,
              tint_color: .tintColor,
              separator_color: .sileoSeparatorColor,
              dark_mode: UIColor.isDarkModeEnabled)
    }
    
    public class func viewController(for package: Package) -> PackageActions {
        if package.nativeDepiction == nil {
            let packageVC = PackageViewController(nibName: "PackageViewController", bundle: nil)
            packageVC.package = package
            return packageVC
        }
        return NativePackageViewController(package: package)
    }
    
    init(package: Package) {
        self.package = package
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let collapsed = splitViewController?.isCollapsed ?? false
        let navController = collapsed ? (splitViewController?.viewControllers[0] as? UINavigationController) : self.navigationController
        navController?.setNavigationBarHidden(true, animated: true)
        
        view.addSubview(scrollView)
        contentView.addSubview(headerImageView)
        contentView.addSubview(depiction)
        contentView.addSubview(packageContainer)
        scrollView.addSubview(contentView)
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.topAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor),
            
            headerImageViewTopAnchor,
            headerImageViewLeadingAnchor,
            headerImageViewTrailingAnchor,
            headerImageViewHeightAnchor,
            
            packageContainer.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            packageContainer.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            packageContainer.topAnchor.constraint(equalTo: headerImageView.bottomAnchor),
            
            depiction.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            depiction.topAnchor.constraint(equalTo: packageContainer.bottomAnchor),
            depiction.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            depiction.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            
            contentView.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            contentView.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
            contentView.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
            contentView.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor)
        ])

        allowNavbarUpdates = true
        navigationController?.navigationBar._backgroundOpacity = 0
        navigationController?.navigationBar.tintColor = .white
        navigationController?.view.backgroundColor = .clear
        statusBarStyle = .lightContent
        navigationItem.largeTitleDisplayMode = .never
        navigationController?.navigationBar.isTranslucent = true
        navigationItem.titleView = packageNavBarIconViewController
        
        extendedLayoutIncludesOpaqueBars = true
        edgesForExtendedLayout = [.top, .bottom]

        scrollView.contentInsetAdjustmentBehavior = .never

        weak var weakSelf = self
        NotificationCenter.default.addObserver(weakSelf as Any,
                                               selector: #selector(updateSileoColors),
                                               name: SileoThemeManager.sileoChangedThemeNotification,
                                               object: nil)
        
        navigationItem.rightBarButtonItems = [navBarShareButtonItem]
        
        /*
        if isModal {
            self.navigationItem.leftBarButtonItem = UIBarButtonItem(title: String(localizationKey: "Done"),
                                                                    style: .done,
                                                                    target: self,
                                                                    action: #selector(NativePackageViewController.dismissImmediately))
        }
        */
        updateSileoColors()
        reloadPackage()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        let collapsed = splitViewController?.isCollapsed ?? false
        let navController = collapsed ? (splitViewController?.viewControllers[0] as? UINavigationController) : navigationController
        
        allowNavbarUpdates = false
        currentNavBarOpacity = navController?.navigationBar._backgroundOpacity ?? 1
        
        UIView.animate(withDuration: 0.8) {
            navController?.navigationBar.tintColor = UINavigationBar.appearance().tintColor
            navController?.navigationBar._backgroundOpacity = 1
        }
    }
    
    private func reloadPackage() {
        if package.packageFileURL == nil {
            if let newestPackage = PackageListManager.shared.newestPackage(identifier: package.package, repoContext: nil) {
                package = newestPackage
            }
        }

        let installedPackage = PackageListManager.shared.installedPackage(identifier: package.package)
        self.installedPackage = installedPackage
        
        if let headerURL = package.rawControl["header"],
           let header = URL(string: headerURL) {
            if header != depictionHeader {
                if let image = EvanderNetworking.shared.image(header, { [weak self] refresh, image in
                    guard let `self` = self,
                          refresh,
                          let image = image else { return }
                    DispatchQueue.main.async { [weak self] in
                        self?.headerImageView.image = image
                    }
                }) {
                    headerImageView.image = image
                }
            }
        } else {
            if var image = UIImage(named: "Background Placeholder") {
                image = ImageProcessing.downsample(image: image) ?? image
                headerImageView.image = image
            }
        }
        if let depiction = package.nativeDepiction {
            EvanderNetworking.request(url: depiction, type: [String: Any].self) { [weak self] success, _, _, dict in
                guard let `self` = self,
                      success,
                      let dict = dict else { return }
                DispatchQueue.main.async { [weak self] in
                    self?.depiction.setDepiction(dict: dict)
                    self?.downloadButton.tintColor = self?.depiction.effectiveTintColor
                    self?.downloadButton.updateStyle()
                    self?.navBarDownloadButton.tintColor = self?.depiction.effectiveTintColor
                    self?.navBarDownloadButton.updateStyle()
                }
            }
        }
        if package.hasIcon(),
            let rawIcon = package.icon {
            let image = EvanderNetworking.shared.image(rawIcon, size: packageIconView.frame.size) { [weak self] refresh, image in
                if refresh,
                    let strong = self,
                    let image = image,
                    strong.package.icon == rawIcon {
                        DispatchQueue.main.async {
                            strong.packageIconView.image = image
                            strong.packageNavBarIconView.image = image
                        }
                }
            } ?? UIImage(named: "Tweak Icon")
            packageIconView.image = image
            packageNavBarIconView.image = image
        }
        
        packageNameLabel.text = package.name
        authorLabel.text = ControlFileParser.authorName(string: package.author ?? "")
        downloadButton.package = package
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        self.statusBarStyle = .default
        
        self.navigationController?.navigationBar._backgroundOpacity = currentNavBarOpacity
        self.navigationController?.navigationBar.tintColor = .white
        allowNavbarUpdates = true
        self.scrollViewDidScroll(self.scrollView)
    }

    @objc func updateSileoColors() {
        depiction.theme = theme
        view.backgroundColor = .sileoBackgroundColor
        downloadButton.tintColor = depiction.effectiveTintColor
        downloadButton.updateStyle()
        navBarDownloadButton.tintColor = depiction.effectiveTintColor
        navBarDownloadButton.updateStyle()
    }
    
    override var previewActionItems: [UIPreviewActionItem] {
        downloadButton.actionItems().map({ $0.previewAction() })
    }
    
    @available (iOS 13.0, *)
    func actions() -> [UIAction] {
        _ = self.view
        return downloadButton.actionItems().map({ $0.action() })
    }
    
    @objc func sharePackage(_ sender: Any?) {
        let sharePopup = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
        let shareAction = UIAlertAction(title: String(localizationKey: "Package_Share_Action"), style: .default) { [weak self] _ in
            guard let `self` = self else { return }
            let package = self.package
            var packageString = "\(package.name ?? package.package) - \(URLManager.url(package: package.package))"
            if let repo = package.sourceRepo {
                packageString += " - from \(repo.url?.absoluteString ?? repo.rawURL)"
            }
            let activityViewController = UIActivityViewController(activityItems: [packageString], applicationActivities: nil)
            activityViewController.popoverPresentationController?.sourceView = self.shareButton
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
        
            let packageSupport = UIAlertAction(title: String(localizationKey: "Package_Support_Action"), style: .default) { [weak self] _ in
                guard let `self` = self else { return }
                let package = self.package
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
        
        if installedPackage != nil {
            let ignoreUpdatesText = installedPackage?.wantInfo == .hold ?
                String(localizationKey: "Package_Hold_Disable_Action") : String(localizationKey: "Package_Hold_Enable_Action")
            let ignoreUpdates = UIAlertAction(title: ignoreUpdatesText, style: .default) { [weak self] _ in
                guard let installedPackage = self?.installedPackage else { return }
                if installedPackage.wantInfo == .hold {
                    installedPackage.wantInfo = .install
                    #if !targetEnvironment(simulator) && !TARGET_SIMULATOR
                    DpkgWrapper.ignoreUpdates(false, package: installedPackage.packageID)
                    #endif
                } else {
                    installedPackage.wantInfo = .hold
                    #if !targetEnvironment(simulator) && !TARGET_SIMULATOR
                    DpkgWrapper.ignoreUpdates(true, package: installedPackage.packageID)
                    #endif
                }
                NotificationCenter.default.post(Notification(name: PackageListManager.prefsNotification))
            }
            sharePopup.addAction(ignoreUpdates)
        }
        
        let wishListText = WishListManager.shared.isPackageInWishList(package.package) ?
            String(localizationKey: "Package_Wishlist_Remove") : String(localizationKey: "Package_Wishlist_Add")
        let wishlist = UIAlertAction(title: wishListText, style: .default) { [weak package] _ in
            guard let package = package else { return }
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
        sharePopup.view.tintColor = depiction.effectiveTintColor
        self.present(sharePopup, animated: true)
    }
    
    @objc func dismissImmediately() {
        // Dismiss this view controller.
        self.dismiss(animated: true, completion: nil)
    }

}

extension NativePackageViewController: DepictionDelegate {
    
    func handleAction(action: DepictionAction) {
        switch action {
        case .openURL(url: let url, external: let external):
            if !external {
                UIApplication.shared.open(url)
            } else {
                let view = SFSafariViewController(url: url)
                self.navigationController?.pushViewController(view, animated: true)
            }
            break
        case .openDepiction(url: let url):
            break
        case .openPackage(bundle: let bundle):
            break
        case .addRepo(url: let url):
            let delegate = UIApplication.shared.delegate as! SileoAppDelegate
            if let tabBarController = delegate.window?.rootViewController as? UITabBarController,
                let sourcesSVC = tabBarController.viewControllers?[2] as? UISplitViewController,
                  let sourcesNavNV = sourcesSVC.viewControllers[0] as? SileoNavigationController {
                  tabBarController.selectedViewController = sourcesSVC
                  if let sourcesVC = sourcesNavNV.viewControllers[0] as? SourcesViewController {
                    sourcesVC.presentAddSourceEntryField(url: url)
                  }
            }
        case .custom(action: let action):
            break
        case .actionError(error: let error, action: let action):
            depictionError(error: "\(error) for \(action)")
        }
    }
    
    func depictionError(error: String) {
        let alert = UIAlertController(title: "Depiction Error", message: error, preferredStyle: .alert)
        alert.view.tintColor = .tintColor
        alert.addAction(UIAlertAction(title: String(localizationKey: "OK"), style: .default, handler: { _ in
            alert.dismiss(animated: true)
        }))
        self.present(alert, animated: true)
    }
    
    func packageView(for package: DepictionPackage) -> UIView {
        let cell: PackageCollectionViewCell = Bundle.main.loadNibNamed("PackageCollectionViewCell", owner: self, options: nil)?[0] as! PackageCollectionViewCell
        let action: PackageControlView = {
            let action = PackageControlView()
            action.backgroundColor = .clear
            action.translatesAutoresizingMaskIntoConstraints = false
            action.addTarget(self, action: #selector(didSelectPackage(_:)), for: .touchUpInside)
            return action
        }()
        cell.contentView.addSubview(action)
        cell.contentView.addConstraints([
            action.topAnchor.constraint(equalTo: cell.contentView.topAnchor),
            action.bottomAnchor.constraint(equalTo: cell.contentView.bottomAnchor),
            action.leadingAnchor.constraint(equalTo: cell.contentView.leadingAnchor),
            action.trailingAnchor.constraint(equalTo: cell.contentView.trailingAnchor),
        ])
        cell.separatorView?.isHidden = true
        let view = cell.contentView
        view.heightAnchor.constraint(equalToConstant: 73).isActive = true
        let packages = PackageListManager.shared.packages(identifiers: [package.identifier], sorted: false)
        if packages.count == 1 {
            cell.targetPackage = packages[0]
            action.package = packages[0]
        } else {
            let provisional = ProvisionalPackage(package: package)
            cell.provisionalTarget = provisional
            action.package = CanisterResolver.package(provisional)
        }
        return view
    }
    
    func image(for url: URL, completion: @escaping ((UIImage?) -> Void)) -> Bool {
        if let image = EvanderNetworking.shared.image(url, cache: true, { refresh, image in
            guard refresh,
                  let image = image else { return }
            completion(image)
        }) {
            completion(image)
        }
        return true
    }
    
    @objc private func didSelectPackage(_ cell: PackageControlView) {
        guard let package = cell.package else { return }
        let viewController = NativePackageViewController.viewController(for: package)
        self.navigationController?.pushViewController(viewController, animated: true)
    }
}

@objc private class PackageControlView: UIControl {
    public var package: Package?
}

extension NativePackageViewController: PackageQueueButtonDataProvider {
    
    func updatePurchaseStatus() {
        guard !isUpdatingPurchaseStatus,
              let sourceRepo = package.sourceRepo else { return }
        isUpdatingPurchaseStatus = true
        let package = package
        PaymentManager.shared.getPaymentProvider(for: sourceRepo) { [weak self] error, provider in
            if error != nil {
                return
            }
            provider?.getPackageInfo(forIdentifier: package.package) { [weak self] error, info in
                guard let info = info,
                    error == nil else {
                    return
                }
                DispatchQueue.main.async {
                    self?.isUpdatingPurchaseStatus = false
                    self?.downloadButton.paymentInfo = info
                    self?.navBarDownloadButton.paymentInfo = info
                }
            }
        }
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        
        self.scrollViewDidScroll(self.scrollView)
    }

}

extension NativePackageViewController: MFMailComposeViewControllerDelegate {
    func mailComposeController(_ controller: MFMailComposeViewController, didFinishWith result: MFMailComposeResult, error: Error?) {
        // Check the result or perform other tasks.

        // Dismiss the mail compose view controller.
        self.dismiss(animated: true, completion: nil)
    }
}

extension NativePackageViewController: UIScrollViewDelegate {
    
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        let headerBounds = headerImageView.bounds
        /*
        var aspectRatio = headerBounds.width / headerBounds.height
        if headerBounds.height == 0 {
            aspectRatio = 0
        }
        */
        var offset = scrollView.contentOffset.y
        if offset > 0 {
            offset = 0
        }
        
        // doing the magic on the nav bar "GET" button and package icon
        let downloadButtonPos = downloadButton.convert(downloadButton.bounds, to: scrollView)
        let container = CGRect(origin: CGPoint(x: scrollView.contentOffset.x,
                                               y: scrollView.contentOffset.y + 106 - UIApplication.shared.statusBarFrame.height),
                               size: scrollView.frame.size)
        // TLDR: magic starts when scrolling out the lower half of the button so we don't have duplicated button too early
        var navBarAlphaOffset = scrollView.contentOffset.y * 1.75 / headerImageViewHeightAnchor.constant
        if headerImageViewHeightAnchor.constant == 0 {
            navBarAlphaOffset = 0
        }

        if navBarAlphaOffset > 1 {
            navBarAlphaOffset = 1
        } else if navBarAlphaOffset < 0 {
            navBarAlphaOffset = 0
        }
        
        UIView.animate(withDuration: 0.3) { [weak self] in
            guard let `self` = self else { return }
            self.shareButton.alpha = 1 - navBarAlphaOffset

            if (self.shareButton.alpha ) > 0 {
                self.packageNavBarIconView.alpha = 0
            } else {
                self.packageNavBarIconView.alpha = downloadButtonPos.intersects(container) ? 0 : 1
            }
            self.navBarDownloadButton.customAlpha = self.packageNavBarIconView.alpha

            if (self.shareButton.alpha) > 0 {
                self.navigationItem.rightBarButtonItems = [self.navBarShareButtonItem]
            } else {
                self.navigationItem.rightBarButtonItems = [self.navBarDownloadButtonItem]
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
            var tintColor = self.depiction.effectiveTintColor
            var red: CGFloat = 0
            var green: CGFloat = 0
            var blue: CGFloat = 0
            tintColor.getRed(&red, green: &green, blue: &blue, alpha: nil)

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
            navController?.navigationBar.tintColor = self.depiction.effectiveTintColor
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
}

extension NativePackageViewController {
    
    public var isModal: Bool {
        let presentingIsModal = presentingViewController != nil
        let presentingIsNavigation = navigationController?.presentingViewController?.presentedViewController == navigationController
        let presentingIsTabBar = tabBarController?.presentingViewController is UITabBarController

        return presentingIsModal || presentingIsNavigation || presentingIsTabBar
    }

}
