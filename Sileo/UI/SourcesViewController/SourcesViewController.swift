//
//  SourcesViewController.swift
//  Sileo
//
//  Created by CoolStar on 9/22/19.
//  Copyright © 2019 CoolStar. All rights reserved.
//

import Foundation

class SourcesViewController: SileoTableViewController {
    private var sortedRepoList: [Repo] = []
    var isRefreshing: Bool = false
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        
        self.checkForUpdatesInBackground()
        
        weak var weakSelf: SourcesViewController? = self
        NotificationCenter.default.addObserver(weakSelf as Any,
                                               selector: #selector(self.checkForUpdatesInBackground),
                                               name: PackageListManager.reloadNotification,
                                               object: nil)
        NotificationCenter.default.addObserver(weakSelf as Any,
                                               selector: #selector(self.reloadRepo(_:)),
                                               name: RepoManager.progressNotification,
                                               object: nil)
    }
    
    func canEditRow(indexPath: IndexPath) -> Bool {
        if indexPath.section == 0 {
            return false
        }
        
        let repo = sortedRepoList[indexPath.row]
        if repo.entryFile.hasSuffix("/sileo.sources") {
            return true
        }
        return false
    }
    
    func controller(indexPath: IndexPath) -> CategoryViewController {
        let categoryVC = CategoryViewController(style: .plain)
        
        categoryVC.title = String(localizationKey: "All_Packages.Title")
        if indexPath.section == 1 {
            let repo = sortedRepoList[indexPath.row]
            categoryVC.repoContext = repo
            categoryVC.title = repo.repoName
        }
        return categoryVC
    }
    
    @objc func checkForUpdatesInBackground() {
        let repoManager = RepoManager.shared
        repoManager.checkUpdatesInBackground {
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.title = String(localizationKey: "Sources_Page")
        
        self.tableView.backgroundColor = .sileoBackgroundColor
        
        weak var weakSelf = self
        NotificationCenter.default.addObserver(weakSelf as Any,
                                               selector: #selector(self.updateSileoColors),
                                               name: SileoThemeManager.sileoChangedThemeNotification,
                                               object: nil)
        
        self.tableView.separatorInset = UIEdgeInsets(top: 72, left: 0, bottom: 0, right: 0)
        self.tableView.separatorColor = UIColor(white: 0, alpha: 0.2)
        self.setEditing(false, animated: false)
        
        self.registerForPreviewing(with: self, sourceView: self.tableView)
        
        self.navigationController?.navigationBar.superview?.tag = WHITE_BLUR_TAG
        
        if !isRefreshing {
            self.refreshSources(forceUpdate: false, forceReload: false)
        }
    }
    
    @objc func updateSileoColors() {
        self.tableView.backgroundColor = UIColor.sileoBackgroundColor
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
        
        self.tableView.backgroundColor = .sileoBackgroundColor
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        
        self.navigationController?.navigationBar._hidesShadow = false
    }
    
    @objc func toggleEditing(_ sender: Any?) {
        self.setEditing(!self.isEditing, animated: true)
    }
    
    override func setEditing(_ editing: Bool, animated: Bool) {
        super.setEditing(editing, animated: animated)
        
        UIView.animate(withDuration: animated ? 0.2 : 0.0) {
            self.navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .add,
                                                                     target: self,
                                                                     action: #selector(self.addSource(_:)))
            if editing {
                self.navigationItem.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: .done,
                                                                        target: self,
                                                                        action: #selector(self.toggleEditing(_:)))
                self.navigationItem.rightBarButtonItem = UIBarButtonItem(title: String(localizationKey: "Export"),
                                                                         style: .plain,
                                                                         target: self,
                                                                         action: #selector(self.exportSources(_:)))
            } else {
                self.navigationItem.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: .edit,
                                                                        target: self,
                                                                        action: #selector(self.toggleEditing(_:)))
            }
        }
    }
    
    @IBAction func refreshSources(_ sender: UIRefreshControl?) {
        self.refreshSources(forceUpdate: true, forceReload: true)
    }
    
    func refreshSources(forceUpdate: Bool, forceReload: Bool) {
        self.refreshSources(useRefreshControl: false, errorScreen: true, forceUpdate: forceUpdate, forceReload: forceReload, isBackground: false, completion: nil)
    }
    
    func refreshSources(useRefreshControl: Bool, errorScreen: Bool, forceUpdate: Bool, forceReload: Bool, isBackground: Bool, completion: ((Bool, NSAttributedString) -> Void)?) {
        self.isRefreshing = true
        
        if useRefreshControl {
            if let tableView = self.tableView, let refreshControl = tableView.refreshControl, !refreshControl.isRefreshing {
                refreshControl.sizeToFit()
                let yVal = -1 * (refreshControl.frame.maxY + tableView.adjustedContentInset.top)
                tableView.setContentOffset(CGPoint(x: 0, y: yVal), animated: true)
                refreshControl.beginRefreshing()
            }
        }
        
        let item = self.splitViewController?.tabBarItem
        item?.badgeValue = ""
        
        guard let style = UIActivityIndicatorView.Style(rawValue: 5) else {
            fatalError("OK iOS...")
        }
        let indicatorView = UIActivityIndicatorView(style: style)
        indicatorView.frame = indicatorView.frame.offsetBy(dx: 2, dy: 2)
        indicatorView.startAnimating()
        
        let badge = item?.view()?.value(forKey: "_badge") as? UIView
        badge?.addSubview(indicatorView)
        
        RepoManager.shared.update(force: forceUpdate, forceReload: forceReload, isBackground: isBackground, completion: { didFindErrors, errorOutput in
            self.refreshControl?.endRefreshing()
            indicatorView.removeFromSuperview()
            indicatorView.stopAnimating()
            item?.badgeValue = nil
            self.isRefreshing = false
            
            if let completion = completion {
                completion(didFindErrors, errorOutput)
            }
            
            if didFindErrors, errorScreen {
                self.showRefreshErrorViewController(errorOutput: errorOutput, completion: nil)
            }
        })
    }
    
    func showRefreshErrorViewController(errorOutput: NSAttributedString, completion: (() -> Void)?) {
        let errorVC = SourcesErrorsViewController(nibName: "SourcesErrorsViewController", bundle: nil)
        errorVC.attributedString = errorOutput
        let navController = UINavigationController(rootViewController: errorVC)
        navController.navigationBar.barStyle = .blackTranslucent
        navController.modalPresentationStyle = .formSheet
        self.present(navController, animated: true, completion: completion)
    }
    
    func reSortList() {
        sortedRepoList = RepoManager.shared.repoList.sorted(by: { obj1, obj2 -> Bool in
            obj1.repoName.localizedCaseInsensitiveCompare(obj2.repoName) == .orderedAscending
        })
    }
    
    @objc func reloadRepo(_ notification: NSNotification) {
        if let repo = notification.object as? Repo {
            guard let idx = sortedRepoList.firstIndex(of: repo),
            let cell = self.tableView.cellForRow(at: IndexPath(row: idx, section: 1)) as? SourcesTableViewCell else { return }
            let cellRepo = cell.repo
            cell.repo = cellRepo
            cell.layoutSubviews()
        } else {
            for cell in tableView.visibleCells {
                if let sourcesCell = cell as? SourcesTableViewCell {
                    let cellRepo = sourcesCell.repo
                    sourcesCell.repo = cellRepo
                    sourcesCell.layoutSubviews()
                }
            }
        }
    }
    
    func reloadData() {
        self.reSortList()
        self.tableView.reloadData()
    }
    
    @objc func exportSources(_ sender: Any?) {
        let titleString = String(localizationKey: "Export")
        let msgString = String(localizationKey: "Export_Sources")
        let alert = UIAlertController(title: titleString, message: msgString, preferredStyle: .alert)
        
        let yesString = String(localizationKey: "Export_Yes")
        let yesAction = UIAlertAction(title: yesString, style: .default, handler: { _ in
            UIPasteboard.general.string = self.sortedRepoList.map({ $0.rawURL }).joined(separator: "\n")
        })
        alert.addAction(yesAction)
        
        let noString = String(localizationKey: "Export_No")
        let noAction = UIAlertAction(title: noString, style: .cancel, handler: { _ in
            self.dismiss(animated: true, completion: nil)
        })
        alert.addAction(noAction)
        
        self.present(alert, animated: true, completion: nil)
    }
    
    public func presentAddSourceEntryField(url: URL?) {
        let title = String(localizationKey: "Add_Source.Title")
        let msg = String(localizationKey: "Add_Source.Body")
        let addSourceController = UIAlertController(title: title, message: msg, preferredStyle: .alert)
        
        addSourceController.addTextField { textField in
            textField.placeholder = "https://coolstar.org/publicrepo"
            if let urlString = url?.absoluteString {
                let parsedURL = urlString.replacingOccurrences(of: "sileo://source/", with: "")
                textField.text = parsedURL
            } else {
                textField.text = "https://"
            }
            textField.keyboardType = .URL
        }
        
        addSourceController.addAction(UIAlertAction(title: String(localizationKey: "Cancel"),
                                                    style: .cancel,
                                                    handler: { _ in
                                                        self.dismiss(animated: true, completion: nil)
        }))
        addSourceController.addAction(UIAlertAction(title: String(localizationKey: "Add_Source.Button.Add"),
                                                    style: .default,
                                                    handler: { _ in
                                                        self.dismiss(animated: true, completion: nil)
                                                        
                                                        if let repoURL = addSourceController.textFields?[0].text,
                                                            let url = URL(string: repoURL) {
                                                            self.handleSourceAdd(urls: [url], bypassFlagCheck: false)
                                                        }
        }))
        
        self.present(addSourceController, animated: true, completion: nil)
    }
    
    func presentAddClipBoardPrompt(sources: [URL]) {
        var message = String(format: String(localizationKey: "Auto_Add_Pasteboard_Sources.Body_Intro"), sources.count)
        message.append(contentsOf: "\n\n")
        let urlsJoined = sources.compactMap { url -> String in
            url.absoluteString
        }.joined(separator: "\n")
        message.append(contentsOf: urlsJoined)
        
        let count = sources.count
        
        let titleText = String(format: String(localizationKey: "Auto_Add_Pasteboard_Sources.Title"), count, count)
        let addButtonText = String(format: String(localizationKey: "Auto_Add_Pasteboard_Sources.Button.Add"), count, count)
        
        let autoPasteboardSourceController = UIAlertController(title: titleText,
                                                               message: message, preferredStyle: .alert)
        autoPasteboardSourceController.addAction(UIAlertAction(title: addButtonText,
                                                               style: .default,
                                                               handler: { _ in
                                                                self.handleSourceAdd(urls: sources, bypassFlagCheck: false)
                                                                self.dismiss(animated: true, completion: nil)
        }))
        autoPasteboardSourceController.addAction(UIAlertAction(title: String(localizationKey: "Auto_Add_Pasteboard_Sources.Button.Manual"),
                                                               style: .default, handler: { _ in
                                                                self.presentAddSourceEntryField(url: nil)
        }))
        autoPasteboardSourceController.addAction(UIAlertAction(title: String(localizationKey: "Cancel"),
                                                               style: .cancel,
                                                               handler: { _ in
                                                                self.dismiss(animated: true, completion: nil)
        }))
        
        self.present(autoPasteboardSourceController, animated: true, completion: nil)
    }
    
    @objc func addSource(_ sender: Any?) {
        // If URL(s) are copied, we ask the user if they want to add those.
        // Otherwise, we present the entry field dialog for the user to type a URL.
        let newSources = UIPasteboard.general.newSources()
        if newSources.isEmpty {
            self.presentAddSourceEntryField(url: nil)
        } else {
            self.presentAddClipBoardPrompt(sources: newSources)
        }
    }
    
    func isSourceFlagged(_ url: URL, completion: @escaping (Bool) -> Void) throws {
        let apiURL = URL(string: "https://flagged-repo-api.getsileo.app/flagged")!
        let requestDict = ["url": url.absoluteString]
        let requestJSON = try JSONSerialization.data(withJSONObject: requestDict, options: [])
        
        var request = URLRequest(url: apiURL)
        request.setValue("application/json; charset=UTF-8", forHTTPHeaderField: "Content-Type")
        request.httpMethod = "POST"
        request.httpBody = requestJSON
        
        URLSession.shared.dataTask(with: request) { (data: Data?, _, error: Error?) in
            if let data = data, error == nil {
                let isBanned = String(data: data, encoding: .utf8)
                return completion(isBanned == "true")
            }
            print("Failed to check for flagged repo with error: \(error?.localizedDescription ?? "")")
            return completion(false)
        }.resume()
    }
    
    func showFlaggedSourceWarningController(url: URL) {
        let flaggedSourceController = FlaggedSourceWarningViewController(nibName: "FlaggedSourceWarningViewController", bundle: nil)
        flaggedSourceController.shouldAddAnywayCallback = {
            self.handleSourceAdd(urls: [url], bypassFlagCheck: true)
            self.refreshSources(forceUpdate: false, forceReload: false)
        }
        flaggedSourceController.url = url
        flaggedSourceController.modalPresentationStyle = .formSheet
        present(flaggedSourceController, animated: true)
    }
    
    func handleSourceAdd(urls: [URL], bypassFlagCheck: Bool) {
        if !bypassFlagCheck {
            for url in urls {
                do {
                    try isSourceFlagged(url) { isFlagged in
                        DispatchQueue.main.async {
                            if isFlagged {
                                return self.showFlaggedSourceWarningController(url: url)
                            }
                            
                            RepoManager.shared.addRepos(with: [url])
                            self.reloadData()
                            self.refreshSources(forceUpdate: false, forceReload: false)
                        }
                    }
                } catch {
                    RepoManager.shared.addRepos(with: [url])
                    self.reloadData()
                    self.refreshSources(forceUpdate: false, forceReload: false)
                }
            }
        } else {
            RepoManager.shared.addRepos(with: urls)
            self.reloadData()
            self.refreshSources(forceUpdate: false, forceReload: false)
        }
    }
}

extension SourcesViewController { // UITableViewDataSource
    override func numberOfSections(in tableView: UITableView) -> Int {
        2
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if section == 0 {
            return 1
        } else {
            self.reSortList()
            return sortedRepoList.count
        }
    }
    
    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        if section == 1 {
            return String(localizationKey: "Repos")
        }
        return nil
    }
    
    override func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        let text = self.tableView(tableView, titleForHeaderInSection: section)
        let headerView = UIView(frame: CGRect(origin: .zero, size: CGSize(width: 320, height: 36)))
        
        if let text = text {
            let headerBlur = UIToolbar(frame: headerView.bounds)
            headerView.tag = WHITE_BLUR_TAG
            headerBlur._hidesShadow = true
            headerBlur.autoresizingMask = [.flexibleWidth, .flexibleBottomMargin]
            headerView.addSubview(headerBlur)
            
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
    
    override func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        switch section {
        case 0:
            return 5
        case 1:
            return 44
        default:
            return 0
        }
    }
    
    override func tableView(_ tableView: UITableView, viewForFooterInSection section: Int) -> UIView? {
        UIView() // do not show extraneous tableview separators
    }
    
    override func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        if section == 0 {
            return 2
        }
        return 0.01
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = (tableView.dequeueReusableCell(withIdentifier: "SourcesViewControllerCellidentifier") as? SourcesTableViewCell) ??
            SourcesTableViewCell(style: .subtitle, reuseIdentifier: "SourcesViewControllerCellidentifier")
        
        if indexPath.section == 0 {
            cell.repo = nil
        } else {
            cell.repo = sortedRepoList[indexPath.row]
        }
        
        return cell
    }
    
    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        55
    }
}

extension SourcesViewController { // UITableViewDelegate
    override func tableView(_ tableView: UITableView, shouldShowMenuForRowAt indexPath: IndexPath) -> Bool {
        indexPath.section > 0
    }
    
    override func tableView(_ tableView: UITableView, canPerformAction action: Selector, forRowAt indexPath: IndexPath, withSender sender: Any?) -> Bool {
        action == #selector(UIResponderStandardEditActions.copy(_:))
    }
    
    override func tableView(_ tableView: UITableView, performAction action: Selector, forRowAt indexPath: IndexPath, withSender sender: Any?) {
        if action != #selector(UIResponderStandardEditActions.copy(_:)) {
            return
        }
        
        let repo = sortedRepoList[indexPath.row]
        UIPasteboard.general.url = repo.url
    }
    
    override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        true
    }
    
    override func tableView(_ tableView: UITableView, editingStyleForRowAt indexPath: IndexPath) -> UITableViewCell.EditingStyle {
        if !self.canEditRow(indexPath: indexPath) {
            return .none
        }
        return .delete
    }
    
    override func tableView(_ tableView: UITableView, shouldIndentWhileEditingRowAt indexPath: IndexPath) -> Bool {
        self.canEditRow(indexPath: indexPath)
    }
    
    override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == .delete && self.canEditRow(indexPath: indexPath) {
            let repoManager = RepoManager.shared
            repoManager.remove(repo: sortedRepoList[indexPath.row])
            
            self.reSortList()
            tableView.deleteRows(at: [indexPath], with: .fade)
            
            self.refreshSources(forceUpdate: false, forceReload: true)
        }
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let categoryVC = self.controller(indexPath: indexPath)
        let navController = SileoNavigationController(rootViewController: categoryVC)
        self.splitViewController?.showDetailViewController(navController, sender: self)
    }
}

extension SourcesViewController: UIViewControllerPreviewingDelegate {
    func previewingContext(_ previewingContext: UIViewControllerPreviewing, viewControllerForLocation location: CGPoint) -> UIViewController? {
        guard let indexPath = self.tableView.indexPathForRow(at: location) else {
            return nil
        }
        
        let categoryVC = self.controller(indexPath: indexPath)
        return categoryVC
    }
    
    func previewingContext(_ previewingContext: UIViewControllerPreviewing, commit viewControllerToCommit: UIViewController) {
        let navController = SileoNavigationController(rootViewController: viewControllerToCommit)
        self.splitViewController?.showDetailViewController(navController, sender: self)
    }
}
