//
//  DepictionFormViewController.swift
//  Sileo
//
//  Created by Amy on 30/04/2021.
//  Copyright © 2021 Amy While. All rights reserved.
//

import UIKit
import Evander

class DepictionFormViewController: SileoTableViewController {
    
    private struct DepictionForm {
        var action: URL?
        var sections = [DepictionFormSection]()
    }

    private struct DepictionFormSection {
        var footerTitle: String?
        var headerTitle: String?
        var rows = [DepictionFormRow]()
    }

    private struct DepictionFormRow {
        var tag: String
        var cellConfigs: [String: Any]?
        
        init(tag: String) {
            self.tag = tag
        }
    }
    
    private var formURL: URL
    private var form = DepictionForm()
    private var loadingView: UIActivityIndicatorView?
    private var submitBarButtonItem: UIBarButtonItem?
    
    var valuesForForm: [String: String] {
        var values = [String: String]()
        if form.sections.isEmpty {
            return values
        }
        for section in 0...(form.sections.count - 1) {
            if form.sections[section].rows.isEmpty { continue }
            for row in 0...(form.sections[section].rows.count - 1) {
                let indexPath = IndexPath(row: row, section: section)
                if let cell = tableView.cellForRow(at: indexPath) as? DepictionFormTextView {
                    let tag = self.form.sections[section].rows[row].tag
                    values[tag] = cell.textField.text
                }
            }
        }
        return values
    }
    
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        self.updateSileoColors()
    }
    
    init(formURL: URL) {
        self.formURL = formURL
        super.init(style: .grouped)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    @objc func updateSileoColors() {
        self.tableView.separatorColor = .sileoSeparatorColor
        if UIColor.isDarkModeEnabled {
            self.tableView.backgroundColor = .sileoBackgroundColor
        } else {
            self.tableView.backgroundColor = .sileoContentBackgroundColor
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.navigationItem.leftBarButtonItem = UIBarButtonItem(title: String(localizationKey: "Cancel"),
                                                                style: .done,
                                                                target: self,
                                                                action: #selector(dismiss(_:)))
        
        let loadingView = UIActivityIndicatorView(style: .gray)
        loadingView.autoresizingMask = [.flexibleLeftMargin, .flexibleRightMargin, .flexibleTopMargin, .flexibleBottomMargin]
        loadingView.center = self.view.center
        self.view.addSubview(loadingView)
        loadingView.hidesWhenStopped = true
        loadingView.startAnimating()
        self.loadingView = loadingView
        tableView.keyboardDismissMode = .onDrag
        let tap = UITapGestureRecognizer(target: view, action: #selector(UIView.endEditing))
        view.addGestureRecognizer(tap)

        self.updateSileoColors()
        weak var weakSelf = self
        NotificationCenter.default.addObserver(weakSelf as Any,
                                               selector: #selector(updateSileoColors),
                                               name: SileoThemeManager.sileoChangedThemeNotification,
                                               object: nil)
        self.loadForm()
    }
    
    @objc private func dismiss(_ : Any?) {
        self.dismiss(animated: true, completion: nil)
    }
    
    private func loadForm() {
        let urlRequest = URLManager.urlRequest(formURL)
        EvanderNetworking.request(request: urlRequest, type: [String: Any].self, cache: .init(localCache: false)) { [weak self] success, _, _, dict in
            guard let strong = self else { return }
            DispatchQueue.main.async {
                strong.loadingView?.stopAnimating()
                guard success,
                      let dict = dict else {
                    strong.presentErrorDialog(message: String(localizationKey: "Form_Load_Error"), mustCancel: true)
                    return
                }
                guard let sections = dict["sections"] as? [[String: Any]] else {
                    strong.presentErrorDialog(message: String(localizationKey: "Invalid_Form_Data"), mustCancel: true)
                    return
                }
                strong.title = dict["title"] as? String ?? String(localizationKey: "Untitled_Form")
                if let action = dict["action"] as? String,
                   let url = URL(string: action),
                   url.isSecure {
                    strong.form.action = url
                    if let confirmButtonText = dict["confirmButtonText"] as? String {
                        strong.submitBarButtonItem = UIBarButtonItem(title: confirmButtonText,
                                                                     style: .done,
                                                                     target: self,
                                                                     action: #selector(DepictionFormViewController.submit(_:)))
                    } else {
                        strong.submitBarButtonItem = UIBarButtonItem(title: String(localizationKey: "Done"),
                                                                     style: .done,
                                                                     target: self,
                                                                     action: #selector(DepictionFormViewController.submit(_:)))
                    }
                    if url.host?.lowercased() != strong.formURL.host?.lowercased() {
                        strong.presentErrorDialog(message: String(localizationKey: "Invalid_Form_Data"), mustCancel: true)
                        return
                    }
                    strong.navigationItem.rightBarButtonItem = strong.submitBarButtonItem
                }
                for section in sections {
                    var formSection = DepictionFormSection()
                    formSection.footerTitle = section["footerTitle"] as? String
                    formSection.headerTitle = section["headerTitle"] as? String
                    if let rows = section["rows"] as? [[String: Any]] {
                        for row in rows {
                            if let tag = row["tag"] as? String {
                                var formRow = DepictionFormRow(tag: tag)
                                formRow.cellConfigs = row["cellConfigs"] as? [String: Any]
                                formSection.rows.append(formRow)
                            }
                        }
                    }
                    strong.form.sections.append(formSection)
                }
                strong.tableView.reloadData()
            }
        }
    }
    
    @objc private func submit(_ : Any?) {
        guard let action = self.form.action else { return }
        self.tableView.isUserInteractionEnabled = false

        let submittingView = UIActivityIndicatorView(style: .gray)
        submittingView.startAnimating()
        self.navigationItem.rightBarButtonItem = UIBarButtonItem(customView: submittingView)
        
        var values = self.valuesForForm
        values["udid"] = UIDevice.current.uniqueIdentifier
        values["device"] = UIDevice.current.platform

        let provider = PaymentManager.shared.getPaymentProvider(for: action.absoluteString)
        if let provider = provider,
            provider.isAuthenticated {
            values["token"] = provider.authenticationToken
        }
        EvanderNetworking.request(url: action, type: [String: Any].self, method: "POST", json: values, cache: .init(localCache: false)) { [weak self] success, _, _, dict in
            guard let strong = self else { return }
            DispatchQueue.main.async {
                guard success,
                      let dict = dict else {
                    strong.presentErrorDialog(message: "An error occurred while submitting the form.", mustCancel: true)
                    return
                }
                guard dict["success"] as? Bool ?? false else {
                    let title = dict["title"] as? String
                    let message = dict["message"] as? String ?? String(localizationKey: "Unknown")
                    strong.presentErrorDialog(title: title,
                                              message: String(format: String(localizationKey: "Form_Submit_Failure", type: .error), message),
                                              mustCancel: true,
                                              retry: true)
                    return
                }
                let title = dict["title"] as? String
                let message = dict["message"] as? String

                let fallbackTitle = success ? String(localizationKey: "Form_Submitted.Default_Title") :
                    String(localizationKey: "Form_Submit_Error.Title", type: .error)
                let fallbackMessage = success ? String(localizationKey: "Form_Submitted.Default_Body") :
                    String(localizationKey: "Unknown", type: .error)

                let alert = UIAlertController(title: title ?? fallbackTitle,
                                              message: message ?? fallbackMessage,
                                              preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: "OK", style: .cancel, handler: { _ in
                    if success {
                        strong.dismiss(animated: true, completion: nil)
                    }
                }))
                strong.present(alert, animated: true, completion: nil)
            }
        }
    }
    
    private func presentErrorDialog(title: String? = nil, message: String, mustCancel: Bool, retry: Bool = false) {
        let alert = UIAlertController(title: (title != nil ? title! : String(localizationKey: "Form_Error.Title", type: .error)),
                                      message: message, preferredStyle: .alert)
        if mustCancel && retry {
            alert.addAction(UIAlertAction(title: "Retry", style: .default) { _ in
                self.submit(nil)
            })
        }
        alert.addAction(UIAlertAction(title: String(localizationKey: mustCancel ? "Cancel" : "OK"),
                                      style: .cancel, handler: { _ in
                                        if mustCancel {
                                            self.dismiss(animated: true, completion: nil)
                                        }
        }))
        self.present(alert, animated: true, completion: nil)
    }

    override func numberOfSections(in tableView: UITableView) -> Int {
        self.form.sections.count
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        self.form.sections[section].rows.count
    }
    
    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        self.form.sections[section].headerTitle
    }
    
    override func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        self.form.sections[section].footerTitle
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = DepictionFormTextView()
        cell.textField.text = ""
        cell.textField.placeholder = ""
        
        if let config = self.form.sections[indexPath.section].rows[indexPath.row].cellConfigs {
            if let placeholder = config["textField.placeholder"] as? String {
                cell.textField.placeholder = placeholder
            }
            if let placeholder = config["placeholder"] as? String {
                cell.textField.placeholder = placeholder
            }
            if let text = config["text"] as? String {
                cell.textField.text = text
            }
        }
        return cell
    }
}
