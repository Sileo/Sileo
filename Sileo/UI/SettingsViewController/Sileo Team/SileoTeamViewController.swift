//
//  SileoTeamViewController.swift
//  Sileo
//
//  Created by Amy on 08/05/2021.
//  Copyright © 2021 Amy While. All rights reserved.
//

import UIKit
import Evander

class SileoTeamViewController: UITableViewController {
    
    var socials = [GithubSocial]()

    override func viewDidLoad() {
        super.viewDidLoad()

        navigationItem.title = String(localizationKey: "Sileo_Team")
        self.tableView.separatorColor = .sileoSeparatorColor
        self.tableView.backgroundColor = .sileoBackgroundColor
        self.tableView.delegate = self
        self.tableView.dataSource = self
        self.tableView.tableFooterView = UIView()
        self.loadSocials()
        
        weak var weakSelf = self
        NotificationCenter.default.addObserver(weakSelf as Any,
                                               selector: #selector(updateSileoColors),
                                               name: SileoThemeManager.sileoChangedThemeNotification,
                                               object: nil)
    }
    
    func render(_ arr: [[String: Any]]) {
        socials.removeAll()
        for item in arr {
            guard let github = item["github"] as? String,
                  let author = item["author"] as? String,
                  let role = item["role"] as? String,
                  let url = item["twitter"] as? String,
                  let twitter = URL(string: url) else { continue }
            let social = GithubSocial(githubProfile: github, author: author, role: role, twitter: twitter)
            socials.append(social)
        }
        self.tableView.reloadData()
    }
    
    private func loadSocials() {
        guard let jsonURL = StoreURL("sileo-team.json") else {
            return
        }
        EvanderNetworking.request(url: jsonURL, type: [[String: Any]].self) { [weak self] success, _, _, array in
            guard success,
                  let array = array else { return }
            DispatchQueue.main.async {
                self?.render(array)
            }
        }
    }
    
    @objc func updateSileoColors() {
        self.tableView.separatorColor = .sileoSeparatorColor
        self.tableView.backgroundColor = .sileoBackgroundColor
        self.tableView.reloadData()
    }
    
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        self.updateSileoColors()
    }

    override func numberOfSections(in tableView: UITableView) -> Int {
        1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        socials.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = GithubSocialCell()
        cell.social = socials[indexPath.row]
        return cell
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        UIApplication.shared.open(socials[indexPath.row].twitter)
        tableView.deselectRow(at: indexPath, animated: true)
    }
}
