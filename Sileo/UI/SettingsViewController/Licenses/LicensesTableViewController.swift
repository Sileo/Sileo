//
//  LicensesTableViewController.swift
//  Sileo
//
//  Created by Jamie Bishop on 30/07/2019.
//  Copyright © 2022 Sileo Team. All rights reserved.
//

import Foundation
import UIKit

class LicensesTableViewController: UITableViewController {
    static let defaultLicensePath = Bundle.main.url(forResource: "Licenses", withExtension: "plist")!
    let licenses: [SourceLicense]
    
    init(path: URL = LicensesTableViewController.defaultLicensePath) {
        guard let licenses = LicenseFile.licensesFrom(url: path) else {
            fatalError("LicensesTableViewController: Failed to parse license file. Is there a file at this path?")
        }
        self.licenses = licenses
        super.init(style: .grouped)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    @objc func updateSileoColors() {
        self.tableView.separatorColor = .sileoSeparatorColor
        self.tableView.backgroundColor = .sileoBackgroundColor
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        navigationItem.title = String(localizationKey: "Licenses_Page_Title")
        
        self.tableView.separatorColor = .sileoSeparatorColor
        self.tableView.backgroundColor = .sileoBackgroundColor
        
        weak var weakSelf = self
        NotificationCenter.default.addObserver(weakSelf as Any,
                                               selector: #selector(updateSileoColors),
                                               name: SileoThemeManager.sileoChangedThemeNotification,
                                               object: nil)
    }
}

// MARK: - Table view data source
extension LicensesTableViewController {
    override func numberOfSections(in tableView: UITableView) -> Int {
        1
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        licenses.count
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = SileoTableViewCell()
        
        let license = licenses[indexPath.row]
        cell.textLabel?.text = license.name
        cell.accessoryType = .disclosureIndicator
        
        return cell
    }
}

// MARK: - Table view delegate
extension LicensesTableViewController {
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let license = licenses[indexPath.row]
        navigationController?.pushViewController(LicenseViewController(with: license), animated: true)
    }
}
