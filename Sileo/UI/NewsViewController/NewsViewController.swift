//
//  NewsViewController.swift
//  Sileo
//
//  Created by Skitty on 2/1/20.
//  Copyright © 2020 CoolStar. All rights reserved.
//

import Foundation

class NewsViewController: SileoViewController, UICollectionViewDataSource, UICollectionViewDelegate, UIViewControllerPreviewingDelegate {
    @IBOutlet var collectionView: UICollectionView!
    @IBOutlet var activityIndicatorView: UIActivityIndicatorView!

    var gradientView: NewsGradientBackgroundView?

    var sortedSections: [Int64] = []
    var sections: [Int64: [Package]] = [:]
    var loadedPackages: Int = 0

    var dateFormatter: DateFormatter = DateFormatter()
    var updateQueue: DispatchQueue = DispatchQueue(label: "org.coolstar.SileoStore.news-update-queue")
    var updateLock = DispatchSemaphore(value: 1)
    var isLoading: Bool = false

    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.title = String(localizationKey: "News_Page")
        
        dateFormatter.dateStyle = DateFormatter.Style.long
        dateFormatter.timeStyle = DateFormatter.Style.short

        collectionView.isHidden = true
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

        self.reloadData()
        
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(reloadData),
                                               name: PackageListManager.didUpdateNotification,
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

        weak var weakSelf = self
        NotificationCenter.default.addObserver(weakSelf as Any,
                                               selector: #selector(reloadData),
                                               name: PackageListManager.didUpdateNotification,
                                               object: nil)
        NotificationCenter.default.addObserver(weakSelf as Any,
                                               selector: #selector(updateSileoColors),
                                               name: SileoThemeManager.sileoChangedThemeNotification,
                                               object: nil)
      
        updateSileoColors()

        if collectionView.isHidden {
            // Invoke a reload now.
            self.reloadData()
        } else {
            // Reload visible items as the user may have switched tabs, marking items as read.
            if self.isBeingPresented {
                collectionView.reloadItems(at: collectionView?.indexPathsForVisibleItems ?? [IndexPath()])
            }
        }
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
    
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            self.collectionView.reloadSections(IndexSet(integer: 0))
        }
    }
}

extension NewsViewController { // Get Data
    @objc func reloadData() {
        updateLock.wait()
        sortedSections = []
        sections = [:]
        loadedPackages = 0
        isLoading = true
        updateLock.signal()

        updateQueue.async {
            PackageListManager.shared.waitForChangesDatabaseReady()

            self.updateLock.wait()
            // Initialise the sections.
            self.sortedSections = PackageStub.timestamps()
            for key in self.sortedSections {
                self.sections[key] = []
            }

            self.updateLock.signal()
            self.isLoading = false
            DispatchQueue.main.async {
                // Scroll to top
                self.collectionView.contentOffset = CGPoint(x: 0, y: -(self.collectionView.safeAreaInsets.top))
                self.loadNextBatch()
            }
        }
    }

    func loadNextBatch() {
        if isLoading {
            return
        }
        self.updateLock.wait()
        isLoading = true
        self.updateLock.signal()

        updateQueue.async {
            self.updateLock.wait()
            let packageListManager = PackageListManager.shared
            packageListManager.waitForChangesDatabaseReady()

            let start = self.loadedPackages
            var toLoad = 100

            let seenPackages = PackageStub.stubs(limit: toLoad, offset: start)
            toLoad = seenPackages.count
                       
            let packageIDs = seenPackages.map { $0.package }
            let packages = packageListManager.packages(identifiers: packageIDs, sorted: false) // __block

            var updatedIndexPaths: [IndexPath] = []

            for (seenPackage, actualPackage) in zip(seenPackages, packages) {
                if actualPackage.package != seenPackage.package {
                    continue
                }
                
                let section = Int64(seenPackage.firstSeenDate.timeIntervalSince1970)
                let itemIndex = self.sections[section]?.count ?? 0
                let sectionIndex = (self.sortedSections.firstIndex(of: section) ?? 0) + 1
                
                actualPackage.userReadDate = seenPackage.userReadDate
                self.sections[section]?.append(actualPackage)
                
                updatedIndexPaths.append(IndexPath(item: itemIndex, section: sectionIndex))
            }

            if !updatedIndexPaths.isEmpty {
                self.loadedPackages += toLoad
            }
            self.isLoading = false
            self.updateLock.signal()

            // Done. Update again so the new cells show up.
            DispatchQueue.main.async {
                // Does this still crash?
                self.collectionView.reloadData()

                // Hide spinner if necessary
                if self.activityIndicatorView.isAnimating {
                    UIView.animate(withDuration: 0.7, animations: {
                        self.activityIndicatorView.alpha = 0
                    }, completion: { _ in
                        self.collectionView.isHidden = false
                        self.activityIndicatorView.stopAnimating()
                    })
                }
            }
        }
    }
}

extension NewsViewController: UICollectionViewDelegateFlowLayout { // Collection View Data Source
    func numberOfSections(in collectionView: UICollectionView) -> Int {
        sortedSections.count + 2
    }

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        if section == 0 {
            return 1
        }
        if section == 1 {
            return sortedSections.isEmpty ? 1 : 0
        }
        updateLock.wait()
        let itemsCount = sections[sortedSections[section - 2]]?.count ?? 0
        updateLock.signal()
        return itemsCount
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        if indexPath.section == 0 {
            let headerView = collectionView.dequeueReusableCell(withReuseIdentifier: "NewsArticlesHeader", for: indexPath)
            return headerView
        } else if indexPath.section == 1 {
            return collectionView.dequeueReusableCell(withReuseIdentifier: "NewsPlaceholderCell", for: indexPath)
        } else {
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "PackageCollectionViewCell",
                                                          for: indexPath) as? PackageCollectionViewCell
            if cell != nil {
                var package: Package?
                if sortedSections.count >= indexPath.section - 2 {
                    updateLock.wait()
                    let sortedSection = sortedSections[indexPath.section - 2]
                    if sections[sortedSection]?.count ?? 0 > indexPath.row {
                        package = sections[sortedSection]?[indexPath.row]
                    }
                    if package != nil {
                        cell?.setTargetPackage(package!, isUnread: package!.userReadDate == nil)
                    }
                    updateLock.signal()
                }
            }
            return cell ?? PackageCollectionViewCell()
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, viewForSupplementaryElementOfKind kind: String, at indexPath: IndexPath) -> UICollectionReusableView {
        if kind == UICollectionView.elementKindSectionHeader {
            let headerView = collectionView.dequeueReusableSupplementaryView(ofKind: kind,
                                                                             withReuseIdentifier: "NewsDateHeader",
                                                                             for: indexPath) as? PackageListHeader ?? PackageListHeader()
            let date = NSDate(timeIntervalSince1970: TimeInterval(sortedSections[indexPath.section - 2]))
            headerView.label?.text = dateFormatter.string(from: date as Date).uppercased(with: Locale.current)
            return headerView
        }
        return UICollectionReusableView()
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, referenceSizeForHeaderInSection section: Int) -> CGSize {
        if section <= 1 {
            return CGSize.zero
        }
        return CGSize(width: collectionView.bounds.size.width, height: 54)
    }

    func collectionView(_ collectionView: UICollectionView, layout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        var width = collectionView.bounds.size.width
        var height: CGFloat = 73
        if indexPath.section == 0 {
            height = 180
        } else if indexPath.section == 1 {
            height = 300
        } else {
            if UIDevice.current.userInterfaceIdiom == UIUserInterfaceIdiom.pad || UIApplication.shared.statusBarOrientation.isLandscape {
                width = min(width, 330)
            }
        }
        return CGSize(width: width, height: height)
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        collectionView.deselectItem(at: indexPath, animated: true)
        if indexPath.section <= 1 {
            return
        }
        let viewController = self.controller(indexPath: indexPath)
        self.navigationController?.pushViewController(viewController, animated: true)
    }

    func collectionView(_ collectionView: UICollectionView, willDisplay cell: UICollectionViewCell, forItemAt indexPath: IndexPath) {
        if indexPath.section == 0 {
            let headerView = cell as? NewsArticlesHeader
            if let viewController = headerView?.viewController {
                self.addChild(viewController)
                viewController.didMove(toParent: self)
            }
        }
    }

    func collectionView(_ collectionView: UICollectionView, didEndDisplaying cell: UICollectionViewCell, forItemAt indexPath: IndexPath) {
        if indexPath.section == 0 {
            let headerView = cell as? NewsArticlesHeader
            if let viewController = headerView?.viewController {
                viewController.removeFromParent()
                viewController.didMove(toParent: nil)
            }
        }
    }
}

extension NewsViewController { // Scroll View Delegate
    func scrollViewWillEndDragging(_ scrollView: UIScrollView, withVelocity velocity: CGPoint, targetContentOffset: UnsafeMutablePointer<CGPoint>) {
        let targetOffset = CGFloat(targetContentOffset.pointee.y)
        // If reaching the bottom, load the next batch of updates
        let distance = scrollView.contentSize.height - (targetOffset + scrollView.bounds.size.height)

        if !isLoading && distance < scrollView.bounds.size.height {
            self.loadNextBatch()
        }
    }
}

extension NewsViewController { // 3D Touch
    func controller(indexPath: IndexPath) -> PackageViewController {
        let packageViewController = PackageViewController(nibName: "PackageViewController", bundle: nil)
        packageViewController.package = sections[sortedSections[indexPath.section - 2]]?[indexPath.row]
        return packageViewController
    }

    func previewingContext(_ previewingContext: UIViewControllerPreviewing, viewControllerForLocation location: CGPoint) -> UIViewController? {
        let indexPath = collectionView?.indexPathForItem(at: location)
        if (indexPath?.section ?? 0) <= 1 {
            return nil
        }
        let packageViewController = self.controller(indexPath: indexPath!)
        return packageViewController
    }

    func previewingContext(_ previewingContext: UIViewControllerPreviewing, commit viewControllerToCommit: UIViewController) {
        self.navigationController?.pushViewController(viewControllerToCommit, animated: true)
    }
}

@available(iOS 13.0, *)
extension NewsViewController {
    func collectionView(_ collectionView: UICollectionView, contextMenuConfigurationForItemAt indexPath: IndexPath, point: CGPoint) -> UIContextMenuConfiguration? {
        if indexPath.section <= 1 {
            return nil
        }
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
