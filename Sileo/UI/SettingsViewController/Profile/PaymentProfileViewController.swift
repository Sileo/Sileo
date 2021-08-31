//
//  PaymentProfileViewController.swift
//  Sileo
//
//  Created by Skitty on 1/27/20.
//  Copyright © 2020 Sileo Team. All rights reserved.
//

import Foundation

class PaymentProfileViewController: BaseSettingsViewController, UICollectionViewDelegate,
    UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {
    private var provider: PaymentProvider?
    private var packages: [Package] = Array()
    private var profileHeaderView: PaymentProfileHeaderView?
    
    private var packageCollectionView: UICollectionView?
    
    private var packageCollectionViewCell: UITableViewCell?

    private var signingOut: Bool = false
    // didSet: This crashes for some reason if there's an error... empty tableView?
    // self.tableView.reloadSections(IndexSet(integersIn: 1...1), with: UITableView.RowAnimation.fade)
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }
    
    override init(style: UITableView.Style) {
        super.init(style: style)
    }
    
    init(provider: PaymentProvider) {
        self.provider = provider
        super.init(style: UITableView.Style.grouped)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.title = String(localizationKey: "Loading")
        
        profileHeaderView = PaymentProfileHeaderView()
        self.headerView = profileHeaderView ?? PaymentProfileHeaderView()
        
        packageCollectionView = UICollectionView(frame: CGRect.zero, collectionViewLayout: UICollectionViewFlowLayout())
        packageCollectionView?.delegate = self
        packageCollectionView?.dataSource = self
        packageCollectionView?.backgroundColor = UIColor.sileoBackgroundColor
        
        let nib: UINib = UINib(nibName: "PackageCollectionViewCell", bundle: nil)
        packageCollectionView?.register(nib, forCellWithReuseIdentifier: "PackageListViewCellIdentifier")
        
        provider?.fetchInfo(fromCache: true) { error, info in
            DispatchQueue.main.async {
                if info == nil {
                    return self.presentFatalPaymentError(error)
                }
                let infoDict =  info as [String: Any]?
                self.profileHeaderView?.info = infoDict ?? [:]
                let name = info?["name"]
                self.title = name as? String ?? ""
            }
        }
        provider?.fetchUserInfo(fromCache: false) { [weak self] error, info in
            guard let strong = self else { return }
            guard let userInfo = info as [String: Any]? else {
                DispatchQueue.main.async {
                    strong.presentFatalPaymentError(error)
                }
                return
            }
            var idents: [String] = []
            if let items = userInfo["items"] as? [String] {
                idents.append(contentsOf: items)
            }
            if let repo = RepoManager.shared.repoList.first(where: { strong.provider?.repoURL == $0.rawURL }) {
                self?.packages = PackageListManager.shared.packages(identifiers: idents, sorted: true, repoContext: repo)
            }
            DispatchQueue.main.async {
                strong.profileHeaderView?.userInfo = userInfo
                strong.packageCollectionView?.reloadData()
                strong.tableView.reloadData()
            }
        }
    }
    
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        if #available(iOS 13, *) {
            packageCollectionView?.backgroundColor = .sileoBackgroundColor
        }
    }
    
    func presentFatalPaymentError(_ error: PaymentError?) {
        let title: String = String(localizationKey: "Settings_Payment_Provider.Profile.Title", type: .error)
        let message: String = error?.message ?? String(localizationKey: "Unknown")
        let alert: UIAlertController = UIAlertController(title: title, message: message, preferredStyle: UIAlertController.Style.alert)
        alert.addAction(UIAlertAction(title: String(localizationKey: "Cancel"), style: UIAlertAction.Style.default) { _ in
            self.navigationController?.popViewController(animated: true)
        })
        alert.addAction(UIAlertAction(title: String(localizationKey: "Payment_Provider_Sign_Out"), style: UIAlertAction.Style.default) { _ in
            self.signingOut = true
            self.provider?.signOut {
                self.signingOut = false
                DispatchQueue.main.async {
                    self.navigationController?.popViewController(animated: true)
                }
            }
        })
        self.present(alert, animated: true)
    }
}

extension PaymentProfileViewController { // Table View Data Source
    override func numberOfSections(in tableView: UITableView) -> Int {
        !packages.isEmpty ? 2 : 1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        1
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if indexPath.section == 0 && !packages.isEmpty {
            if !packages.isEmpty {
                if packageCollectionViewCell == nil {
                    packageCollectionViewCell = CollectionViewTableViewCell(collectionView: packageCollectionView ?? UICollectionView())
                }
                return packageCollectionViewCell ?? UITableViewCell()
            }
            let cell: UITableViewCell = self.reusableCell(withStyle: UITableViewCell.CellStyle.default, reuseIdentifier: "NoItemsCellIdentifier")
            cell.tintColor = UIColor.gray
            cell.textLabel?.text = String(localizationKey: "Settings_Payment_Provider.No_Purchases")
            cell.selectionStyle = UITableViewCell.SelectionStyle.none
            return cell
        } else if indexPath.section == 1 || (indexPath.section == 0 && packages.isEmpty) {
            let cell: UITableViewCell = self.reusableCell(withStyle: UITableViewCell.CellStyle.default, reuseIdentifier: "NoItemsCellIdentifier")
            cell.tintColor = UIColor.systemRed
            cell.textLabel?.text = String(localizationKey: "Payment_Provider_Sign_Out")
            if self.signingOut {
                let loadingView: UIActivityIndicatorView = UIActivityIndicatorView(style: UIActivityIndicatorView.Style.gray)
                loadingView.startAnimating()
                cell.accessoryView = loadingView
            } else {
                cell.accessoryType = UITableViewCell.AccessoryType.disclosureIndicator
            }
            cell.selectionStyle = self.signingOut ? UITableViewCell.SelectionStyle.none : UITableViewCell.SelectionStyle.default
            return cell
        }
        return UITableViewCell()
    }

    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String {
        if section == 0 {
            return String(localizationKey: "Settings_Payment_Provider.Purchases_Heading")
        }
        return ""
    }

    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        if indexPath.section == 0 && !packages.isEmpty {
            return UITableView.automaticDimension
        }
        return super.tableView(tableView, heightForRowAt: indexPath)
    }
}

extension PaymentProfileViewController { // Table View Delegate
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if (indexPath.section == 1 || (indexPath.section == 0 && packages.isEmpty)) && !self.signingOut {
            let info = provider?.info
            let name = info?["name"] as? String
            let signOutTitle = String(localizationKey: "Payment_Provider_Sign_Out_Confirm.Title")
            
            let title: String = (name != nil) ? String(format: signOutTitle, name ?? "") : signOutTitle
            let message: String = String(localizationKey: "Payment_Provider_Sign_Out_Confirm.Body")
            let alert: UIAlertController = UIAlertController(title: title, message: message, preferredStyle: UIAlertController.Style.actionSheet)
            
            alert.addAction(UIAlertAction(title: String(localizationKey: "Payment_Provider_Sign_Out"), style: UIAlertAction.Style.destructive) { _ in
                self.signingOut = true
                self.provider?.signOut {
                    DispatchQueue.main.async {
                        self.signingOut = false
                        self.navigationController?.popViewController(animated: true)
                    }
                }
                self.provider?.invalidateSavedToken()
            })
            alert.addAction(UIAlertAction(title: String(localizationKey: "Cancel"), style: UIAlertAction.Style.cancel))
            if let popoverController = alert.popoverPresentationController {
                guard let cellcv = tableView.cellForRow(at: indexPath)?.contentView else {
                    return
                }
                popoverController.sourceView = cellcv
                popoverController.sourceRect = CGRect(x: cellcv.bounds.midX, y: cellcv.bounds.midY, width: 0, height: 0)
            }
            self.present(alert, animated: true)
        }
        tableView.deselectRow(at: indexPath, animated: true)
    }
}

extension PaymentProfileViewController { // Collection View Data Source
    func numberOfSections(in collectionView: UICollectionView) -> Int {
        1
    }
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        packages.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt path: IndexPath) -> UICollectionViewCell {
        let id = "PackageListViewCellIdentifier"
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: id, for: path) as? PackageCollectionViewCell
        
        if cell != nil {
            cell?.alwaysHidesSeparator = true
            cell?.targetPackage = packages[path.row]
            return cell ?? UICollectionViewCell()
        }
        
        return PackageCollectionViewCell()
    }
}

extension PaymentProfileViewController { // Collection View Delegate
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let cell: PackageCollectionViewCell? = self.collectionView(collectionView, cellForItemAt: indexPath) as? PackageCollectionViewCell
        cell?.backgroundColor = UIColor.lightGray.withAlphaComponent(0.5)
        collectionView.deselectItem(at: indexPath, animated: true)
        
        self.navigationController?.pushViewController(NativePackageViewController.viewController(for: packages[indexPath.row]), animated: true)
    }
}

extension PaymentProfileViewController { // Collection View Layout
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        var width: CGFloat = collectionView.bounds.size.width
        if UIDevice.current.userInterfaceIdiom == UIUserInterfaceIdiom.pad ||
            UIApplication.shared.statusBarOrientation.isLandscape {
            if width > 330 {
                width = 330
            }
        }
        if indexPath.section == 0 {
            return CGSize(width: width, height: 70)
        } else {
            return CGSize(width: width, height: 54)
        }
    }
}
