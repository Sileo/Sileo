//
//  LanguageSelectionViewController.swift
//  Sileo
//
//  Created by Andromeda on 03/08/2021.
//  Copyright © 2021 Sileo Team. All rights reserved.
//

import UIKit

class LanguageSelectionViewController: BaseSettingsViewController, LanguageSelectionCellProtocol {
    
    public var useSystemLanguage = UserDefaults.standard.bool(forKey: "UseSystemLanguage")
    public var chosenCode = UserDefaults.standard.string(forKey: "SelectedLanguage")
    private var isFired = false
    
    override var prefersStatusBarHidden: Bool {
        return isFired
    }
    
    enum Section {
        case systemLanguage
        case languageList
        case helpLocalize
    }
    
    private func sectionType(for section: Int) -> Section {
        if section == 0 {
            return .systemLanguage
        } else if useSystemLanguage || section == 2 {
            return .helpLocalize
        } else {
            return .languageList
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        navigationItem.title = String(localizationKey: "Language")
        navigationItem.rightBarButtonItem = UIBarButtonItem(title: String(localizationKey: "Apply_Changes"), style: .done, target: self, action: #selector(appylyChanges))
    }
    
    @objc private func appylyChanges() {
        let alert = UIAlertController(title: String(localizationKey: "Apply_Changes"),
                                      message: String(localizationKey: "Apply_Changes_Confirm"),
                                      preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: String(localizationKey: "After_Install_Relaunch"), style: .destructive, handler: { _ in
            UserDefaults.standard.setValue(self.useSystemLanguage, forKey: "UseSystemLanguage")
            if let selectedLanguage = self.chosenCode {
                UserDefaults.standard.setValue(selectedLanguage, forKey: "SelectedLanguage")
            }
            UserDefaults.standard.synchronize()
            guard let window = UIApplication.shared.windows.first else { exit(0) }
            self.isFired = true
            self.setNeedsStatusBarAppearanceUpdate()
            let animator = UIViewPropertyAnimator(duration: 0.3, dampingRatio: 1) {
                window.alpha = 0
                window.transform = .init(scaleX: 0.9, y: 0.9)
            }
            animator.addCompletion { _ in
                exit(0)
            }
            animator.startAnimation()
        }))
        alert.addAction(UIAlertAction(title: String(localizationKey: "Cancel"), style: .cancel, handler: { _ in
            alert.dismiss(animated: true)
        }))
        alert.view.tintColor = .tintColor
        self.present(alert, animated: true)
    }

    // MARK: - Table view data source

    override func numberOfSections(in tableView: UITableView) -> Int {
        2 + (useSystemLanguage ? 0 : 1)
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch sectionType(for: section) {
        case .helpLocalize, .systemLanguage: return 1
        case .languageList: return LanguageHelper.shared.availableLanguages.count
        }
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        switch sectionType(for: indexPath.section) {
        case .languageList:
            let language = LanguageHelper.shared.availableLanguages[indexPath.row]
            let cell: UITableViewCell = self.reusableCell(withStyle: .subtitle, reuseIdentifier: "LangaugeCellShared")
            cell.textLabel?.text = language.displayName
            cell.detailTextLabel?.text = language.localizedDisplay
            if language.key == chosenCode {
                cell.accessoryType = .checkmark
            }
            return cell
        case .helpLocalize:
            let cell: UITableViewCell = self.reusableCell(withStyle: .default, reuseIdentifier: "HelpLocalize")
            cell.accessoryType = .disclosureIndicator
            cell.textLabel?.text = String(localizationKey: "Help_Translate")
            return cell
        case .systemLanguage:
            let cell = LanguageSelectionCell()
            cell.delegate = self
            cell.control.isOn = useSystemLanguage
            return cell
        }
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        switch sectionType(for: indexPath.section) {
        case .helpLocalize: UIApplication.shared.open(URL(string: "https://crowdin.com/project/sileo")!)
        case .languageList:
            for cell in tableView.visibleCells where cell.reuseIdentifier == "LangaugeCellShared" {
                cell.accessoryType = .none
            }
            let cell = tableView.cellForRow(at: indexPath)
            cell?.accessoryType = .checkmark
            let language = LanguageHelper.shared.availableLanguages[indexPath.row]
            chosenCode = language.key
        case .systemLanguage: return
        }
    }
    
    func didChange(state: Bool) {
        useSystemLanguage = state
        if state {
            tableView.deleteSections(IndexSet(integer: 1), with: .automatic)
        } else {
            tableView.insertSections(IndexSet(integer: 1), with: .automatic)
        }
    }
    
}
