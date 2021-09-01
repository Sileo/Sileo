//
//  NativePackageViewController.swift
//  Sileo
//
//  Created by Andromeda on 31/08/2021.
//  Copyright © 2021 Sileo Team. All rights reserved.
//

import UIKit
import DepictionKit

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
    
    public lazy var downloadButton: PackageQueueButton = {
        let button = PackageQueueButton()
        button.translatesAutoresizingMaskIntoConstraints = false
        button.dataProvider = self
        button.setContentHuggingPriority(UILayoutPriority(252), for: .horizontal)
        button.setContentCompressionResistancePriority(UILayoutPriority(752), for: .horizontal)
        
        return button
    }()
    public var packageIconView: PackageIconView = {
        let view = PackageIconView()
        view.translatesAutoresizingMaskIntoConstraints = false
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
            downloadButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -10),
            downloadButton.leadingAnchor.constraint(equalTo: labelContainer.trailingAnchor, constant: -10)
        ])
        return view
    }()
    
    public lazy var depiction: DepictionContainer = {
        let depiction = DepictionContainer(presentationController: self, theme: theme)
        depiction.delegate = self
        return depiction
    }()
    
    public var headerImageView: UIImageView = {
        let view = UIImageView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.contentMode = .scaleAspectFill
        view.heightAnchor.constraint(equalToConstant: 200).isActive = true
        return view
    }()
    
    public var scrollView: UIScrollView = {
        let view = UIScrollView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.backgroundColor = .clear
        return view
    }()
    public var contentView: UIView = {
        let view = UIView()
        view.backgroundColor = .clear
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

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
        
        view.addSubview(scrollView)
        contentView.addSubview(headerImageView)
        contentView.addSubview(depiction)
        contentView.addSubview(packageContainer)
        scrollView.addSubview(contentView)
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.topAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            
            contentView.topAnchor.constraint(equalTo: headerImageView.topAnchor),
            contentView.leadingAnchor.constraint(equalTo: headerImageView.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: headerImageView.trailingAnchor),
            
            packageContainer.leadingAnchor.constraint(equalTo: headerImageView.leadingAnchor),
            packageContainer.trailingAnchor.constraint(equalTo: headerImageView.trailingAnchor),
            packageContainer.topAnchor.constraint(equalTo: headerImageView.bottomAnchor),
            
            depiction.leadingAnchor.constraint(equalTo: headerImageView.leadingAnchor),
            depiction.topAnchor.constraint(equalTo: packageContainer.bottomAnchor),
            depiction.trailingAnchor.constraint(equalTo: headerImageView.trailingAnchor),
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
        statusBarStyle = .lightContent
        navigationItem.largeTitleDisplayMode = .never
        navigationController?.navigationBar.isTranslucent = true
        
        extendedLayoutIncludesOpaqueBars = true
        edgesForExtendedLayout = [.top, .bottom]
        
        weak var weakSelf = self
        NotificationCenter.default.addObserver(weakSelf as Any,
                                               selector: #selector(updateSileoColors),
                                               name: SileoThemeManager.sileoChangedThemeNotification,
                                               object: nil)
        
        updateSileoColors()
        reloadPackage()
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
                if let image = AmyNetworkResolver.shared.image(header, { [weak self] refresh, image in
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
                image = GifController.downsample(image: image) ?? image
                headerImageView.image = image
            }
        }
        if let depiction = package.nativeDepiction {
            AmyNetworkResolver.dict(url: depiction, cache: true) { [weak self] refresh, dict in
                guard let `self` = self,
                      refresh,
                      let dict = dict else { return }
                DispatchQueue.main.async { [weak self] in
                    self?.depiction.setDepiction(dict: dict)
                    NSLog("[Sileo] \(self?.depiction.bounds) \(self?.contentView.bounds) \(self?.scrollView.bounds)")
                }
            }
        }
        if package.hasIcon(),
            let rawIcon = package.icon {
            let image = AmyNetworkResolver.shared.image(rawIcon, size: packageIconView.frame.size) { [weak self] refresh, image in
                if refresh,
                    let strong = self,
                    let image = image,
                    strong.package.icon == rawIcon {
                        DispatchQueue.main.async {
                            strong.packageIconView.image = image
                            //strong.packageNavBarIconView.image = image
                        }
                }
            } ?? UIImage(named: "Tweak Icon")
            packageIconView.image = image
            //packageNavBarIconView?.image = image
        }
        
        packageNameLabel.text = package.name
        authorLabel.text = ControlFileParser.authorName(string: package.author ?? "")
        downloadButton.package = package
    }

    @objc func updateSileoColors() {
        depiction.theme = theme
        view.backgroundColor = .sileoBackgroundColor
    }
    
    @available (iOS 13.0, *)
    func actions() -> [UIAction] {
        _ = self.view
        return downloadButton.actionItems().map({ $0.action() })
    }

}

extension NativePackageViewController: DepictionDelegate {
    
    func openURL(_ url: URL, completionHandler: @escaping (Bool) -> Void) {
        completionHandler(false)
    }
    
    func handleAction(action: String, external: Bool) {
        
    }

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
                    //self.navBarDownloadButton?.paymentInfo = info
                }
            }
        }
    }

}
