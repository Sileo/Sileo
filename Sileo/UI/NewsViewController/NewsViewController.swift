//
//  NewsViewController.swift
//  Sileo
//
//  Created by Skitty on 2/1/20.
//  Copyright © 2020 Sileo Team. All rights reserved.
//

import Foundation

fileprivate enum NewsSection {
    case placeholder
    case news
    case packages
}

class NewsViewController: SileoViewController, UICollectionViewDataSource, UICollectionViewDelegate, UIViewControllerPreviewingDelegate {
    @IBOutlet var collectionView: UICollectionView!
    @IBOutlet var activityIndicatorView: UIActivityIndicatorView!
    
    static let reloadNotification = Notification.Name("SileoNewPageReload")
    
    var gradientView: NewsGradientBackgroundView?

    private var sections = [Int64: [Package]]()
    private var timestamps = [Int64]()

    var dateFormatter: DateFormatter = DateFormatter()
    private var updateQueue: DispatchQueue = DispatchQueue(label: "org.coolstar.SileoStore.news-update-queue", qos: .userInitiated)
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()

        _ = NewsResolver.shared
        
        self.title = String(localizationKey: "News_Page")
        
        dateFormatter.dateStyle = DateFormatter.Style.long
        dateFormatter.timeStyle = DateFormatter.Style.short
        if let locale = LanguageHelper.shared.locale {
            dateFormatter.locale = locale
        }

        collectionView.isHidden = true
        self.activityIndicatorView.startAnimating()
        let flowLayout: UICollectionViewFlowLayout? = collectionView?.collectionViewLayout as? UICollectionViewFlowLayout
        flowLayout?.sectionHeadersPinToVisibleBounds = true
        
        collectionView.register(UINib(nibName: "PackageCollectionViewCell", bundle: nil),
                                forCellWithReuseIdentifier: "PackageCollectionViewCell")
        collectionView.register(UINib(nibName: "NewsPlaceholderCollectionViewCell", bundle: nil),
                                forCellWithReuseIdentifier: "NewsPlaceholderCell")
        collectionView.register(UINib(nibName: "PackageListHeader", bundle: nil),
                                forSupplementaryViewOfKind: UICollectionView.elementKindSectionHeader,
                                withReuseIdentifier: "PackageListHeader")
        collectionView.register(UINib(nibName: "NewsDateHeader", bundle: nil),
                                forSupplementaryViewOfKind: UICollectionView.elementKindSectionHeader,
                                withReuseIdentifier: "NewsDateHeader")
        collectionView.register(NewsArticlesHeader.self,
                                forCellWithReuseIdentifier: "NewsArticlesHeader")

        self.registerForPreviewing(with: self, sourceView: self.collectionView)
        
        weak var weakSelf = self
        NotificationCenter.default.addObserver(weakSelf as Any,
                                               selector: #selector(reloadData),
                                               name: PackageListManager.didUpdateNotification,
                                               object: nil)
        NotificationCenter.default.addObserver(weakSelf as Any,
                                               selector: #selector(updateSileoColors),
                                               name: SileoThemeManager.sileoChangedThemeNotification,
                                               object: nil)
        NotificationCenter.default.addObserver(weakSelf as Any,
                                               selector: #selector(reloadData),
                                               name: NewsViewController.reloadNotification,
                                               object: nil)
    }
    
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

        self.navigationController?.navigationBar.superview?.tag = WHITE_BLUR_TAG
        self.navigationController?.navigationBar._hidesShadow = true
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)

        self.navigationController?.navigationBar._hidesShadow = false
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        
        // Mark any visible cells as seen
        let visibleIndexes = collectionView.indexPathsForVisibleItems
        for indexPath in visibleIndexes {
            if currentSection(indexPath.section) == .packages {
                markAsSeen(indexPath)
            }
        }
    }
    
    /*
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            self.collectionView.reloadSections(IndexSet(integer: 0))
        }
    }
    */
}

extension NewsViewController { // Get Data
    @objc func reloadData() {
        DispatchQueue.main.async {
            self.collectionView.isHidden = true
            self.activityIndicatorView.startAnimating()
            self.activityIndicatorView.isHidden = false
            self.activityIndicatorView.alpha = 1.0
            self.loadNextBatch()
        }
    }
    
    func loadNextBatch() {
        updateQueue.async {
            let packageListManager = PackageListManager.shared
            let databaseManager = DatabaseManager.shared
            
            let timestampsWeCareAbout = PackageStub.timestamps().sorted { $0 > $1 }
            if timestampsWeCareAbout.isEmpty {
                DispatchQueue.main.async {
                    if self.activityIndicatorView.isAnimating {
                        UIView.animate(withDuration: 0.3, animations: {
                            self.activityIndicatorView.alpha = 0
                        }, completion: { _ in
                            self.collectionView.isHidden = false
                            self.activityIndicatorView.stopAnimating()
                        })
                    }
                }
                return
            }
            // Ok so we've got a list of timestamps we haven't bothered to load yet
            // We're gonna load the batches, until we get to 100 or over
            // Thanks to new repo contexts, loading packages is signifcantly faster anyway
            var stubs = ContiguousArray<PackageStub>()
            for timestamp in timestampsWeCareAbout {
                stubs += databaseManager.stubsAtTimestamp(timestamp)
            }
            
            // Going to take advantage of those sweet contexts and dictionaries for super speedy package loads
            var packages = [Int64: ContiguousArray<Package>]()
            var packageCache: [String: [(String, Int64, Bool)]] = [:]
            for stub in stubs {
                if var packages = packageCache[stub.repoURL] {
                    packages.append((stub.package, stub.firstSeen ?? 0, stub.userReadDate == 1))
                    packageCache[stub.repoURL] = packages
                } else {
                    packageCache[stub.repoURL] = [(stub.package, stub.firstSeen ?? 0, stub.userReadDate == 1)]
                }
            }

            // Find each package and organise into a nice dictionary
            for key in packageCache.keys {
                let repo = RepoManager.shared.repoList.first(where: { RepoManager.shared.cacheFile(named: "Packages", for: $0).lastPathComponent == key })
                let localPackages = packageCache[key] ?? []
                for package in localPackages {
                    if let package2 = repo?.packageDict[package.0] {
                        package2.userRead = package.2
                        if var packages2 = packages[package.1] {
                            packages2.append(package2)
                            packages[package.1] = packages2
                        } else {
                            packages[package.1] = [package2]
                        }
                    }
                }
            }
            // Sort the packages array based on name and size
            for timestamp in packages.keys {
                let packageArray = packages[timestamp] ?? []
                let sorted = packageListManager.sortPackages(packages: Array(packageArray), search: nil)
                packages[timestamp] = ContiguousArray(sorted)
            }
            // Merge with the master array
            // This is the dumbest shit ever, it's literally the master array that shows
            // swiftlint:disable inclusive_language
            var master = self.sections
            master.removeAll()
            for timestamp in packages.keys {
                if let packages = packages[timestamp],
                      !packages.isEmpty {
                    master[timestamp] = Array(packages)
                }
            }
            DispatchQueue.main.async {
                // Set our final new dictionary
                // We do this on the main thread to avoid a mismatch somehow
                self.sections = master
                self.timestamps = Array(master.keys).sorted { $0 > $1 }
                self.collectionView.reloadData()

                // Hide spinner if necessary
                if self.activityIndicatorView.isAnimating {
                    UIView.animate(withDuration: 0.3, animations: {
                        self.activityIndicatorView.alpha = 0
                    }, completion: { _ in
                        self.collectionView.isHidden = false
                        self.activityIndicatorView.stopAnimating()
                    })
                }
            }
        }
    }
    
    private func currentSection(_ section: Int) -> NewsSection {
        if NewsResolver.shared.showNews {
            switch section {
            case 0: return .news
            case 1: return .placeholder
            default: return .packages
            }
        }
        switch section {
        case 0: return .placeholder
        default: return .packages
        }
    }
}

extension NewsViewController: UICollectionViewDelegateFlowLayout { // Collection View Data Source
    
    private var newsBuffer: Int {
        NewsResolver.shared.showNews ? 2 : 1
    }
    
    func numberOfSections(in collectionView: UICollectionView) -> Int {
        timestamps.count + newsBuffer
    }

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        switch currentSection(section) {
        case .news: return 1
        case .placeholder: return sections.isEmpty ? 1 : 0
        case .packages: return sections[timestamps[section - newsBuffer]]?.count ?? 0
        }
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        switch currentSection(indexPath.section) {
        case .news: return collectionView.dequeueReusableCell(withReuseIdentifier: "NewsArticlesHeader", for: indexPath)
        case .placeholder: return collectionView.dequeueReusableCell(withReuseIdentifier: "NewsPlaceholderCell", for: indexPath)
        case .packages:
            guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "PackageCollectionViewCell",
                                                                for: indexPath) as? PackageCollectionViewCell,
                  let package = sections[timestamps[indexPath.section - newsBuffer]]?[indexPath.row] else { return PackageCollectionViewCell() }
            cell.setTargetPackage(package, isUnread: !package.userRead)
            return cell
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, viewForSupplementaryElementOfKind kind: String, at indexPath: IndexPath) -> UICollectionReusableView {
        if kind == UICollectionView.elementKindSectionHeader {
            let headerView = collectionView.dequeueReusableSupplementaryView(ofKind: kind,
                                                                             withReuseIdentifier: "NewsDateHeader",
                                                                             for: indexPath) as? PackageListHeader ?? PackageListHeader()
            let date = NSDate(timeIntervalSince1970: TimeInterval(timestamps[indexPath.section - newsBuffer]))
            headerView.label?.text = dateFormatter.string(from: date as Date).uppercased(with: Locale.current)
            return headerView
        }
        return UICollectionReusableView()
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, referenceSizeForHeaderInSection section: Int) -> CGSize {
        switch currentSection(section) {
        case .news, .placeholder: return CGSize.zero
        case .packages: return CGSize(width: collectionView.bounds.size.width, height: 54)
        }
    }

    func collectionView(_ collectionView: UICollectionView, layout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        var width = collectionView.bounds.size.width
        var height: CGFloat = 73
        switch currentSection(indexPath.section) {
        case .news: height = 180
        case .placeholder: height = 300
        case .packages:
            if UIDevice.current.userInterfaceIdiom == UIUserInterfaceIdiom.pad || UIApplication.shared.statusBarOrientation.isLandscape {
                width = min(width, 330)
            }
        }
        return CGSize(width: width, height: height)
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        collectionView.deselectItem(at: indexPath, animated: true)
        if currentSection(indexPath.section) != .packages { return }
        let viewController = self.controller(indexPath: indexPath)
        self.navigationController?.pushViewController(viewController, animated: true)
    }

    func collectionView(_ collectionView: UICollectionView, willDisplay cell: UICollectionViewCell, forItemAt indexPath: IndexPath) {
        let currentSection = currentSection(indexPath.section)
        if currentSection == .news {
            let headerView = cell as? NewsArticlesHeader
            if let viewController = headerView?.viewController {
                self.addChild(viewController)
                viewController.didMove(toParent: self)
            }
            return
        } else if currentSection == .packages {
            markAsSeen(indexPath)
        }
    }

    func collectionView(_ collectionView: UICollectionView, didEndDisplaying cell: UICollectionViewCell, forItemAt indexPath: IndexPath) {
        let currentSection = currentSection(indexPath.section)
        if currentSection == .news {
            let headerView = cell as? NewsArticlesHeader
            if let viewController = headerView?.viewController {
                viewController.removeFromParent()
                viewController.didMove(toParent: nil)
            }
        }
    }
    
    private func markAsSeen(_ indexPath: IndexPath) {
        guard let safe = timestamps.safe(indexPath.section - newsBuffer),
              let section = sections[safe] else { return }
        let package = section[indexPath.row]
        DatabaseManager.shared.markAsSeen(package)
        sections[timestamps[indexPath.section - newsBuffer]]?[indexPath.row].userRead = true
    }
}

extension NewsViewController { // 3D Touch
    func controller(indexPath: IndexPath) -> PackageActions {
        guard let package = sections[timestamps[indexPath.section - newsBuffer]]?[indexPath.row] else { fatalError("Something went wrong with indexxing") }
        return NativePackageViewController.viewController(for: package)
    }

    func previewingContext(_ previewingContext: UIViewControllerPreviewing, viewControllerForLocation location: CGPoint) -> UIViewController? {
        guard let indexPath = collectionView?.indexPathForItem(at: location) else { return nil }
        if currentSection(indexPath.section) != .packages { return nil }
        let packageViewController = self.controller(indexPath: indexPath)
        return packageViewController
    }

    func previewingContext(_ previewingContext: UIViewControllerPreviewing, commit viewControllerToCommit: UIViewController) {
        self.navigationController?.pushViewController(viewControllerToCommit, animated: true)
    }
}

@available(iOS 13.0, *)
extension NewsViewController {
    func collectionView(_ collectionView: UICollectionView, contextMenuConfigurationForItemAt indexPath: IndexPath, point: CGPoint) -> UIContextMenuConfiguration? {
        if currentSection(indexPath.section) != .packages { return nil }
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
        if let controller = animator.previewViewController {
            animator.addAnimations {
                self.show(controller, sender: self)
            }
        }
    }
}

extension Array {
    func safe(_ index: Int) -> Element? {
        if (self.count - 1) < index { return nil }
        return self[index]
    }
}
