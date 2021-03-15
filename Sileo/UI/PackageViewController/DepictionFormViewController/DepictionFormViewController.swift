//
//  DepictionFormViewController.swift
//  Sileo
//
//  Created by CoolStar on 8/16/20.
//  Copyright © 2020 CoolStar. All rights reserved.
//

import UIKit
import Alamofire
import SwiftTryCatch
import XLForm
import os.log

enum DepictionFormError: Error {
    case hostOriginException
}

class DepictionFormViewController: XLFormViewController {
    public var formURL: URL?
    private var formAction = ""
    private var loadingView: UIActivityIndicatorView?
    private var submitBarButtonItem: UIBarButtonItem?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.navigationItem.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: .cancel, target: self, action: #selector(DepictionFormViewController.dismiss(_:)))
        
        let loadingView = UIActivityIndicatorView(style: .gray)
        loadingView.autoresizingMask = [.flexibleLeftMargin, .flexibleRightMargin, .flexibleTopMargin, .flexibleBottomMargin]
        loadingView.center = self.view.center
        self.view.addSubview(loadingView)
        loadingView.hidesWhenStopped = true
        loadingView.startAnimating()
        self.loadingView = loadingView
        
        guard let formURL = formURL else {
            self.presentErrorDialog(message: String(localizationKey: "Form_Load_Error"), mustCancel: true)
            return
        }
        let urlRequest = URLManager.urlRequest(formURL)
        let task = URLSession.shared.dataTask(with: urlRequest) { rawData, _, _ in
            guard let rawData = rawData else {
                self.presentErrorDialog(message: String(localizationKey: "Form_Load_Error"), mustCancel: true)
                return
            }
            guard let rawForm = try? JSONSerialization.jsonObject(with: rawData, options: []) as? [String: Any] else {
                self.presentErrorDialog(message: String(localizationKey: "Invalid_Form_Data"), mustCancel: true)
                return
            }
            
            DispatchQueue.main.async {
                do {
                    try self.populateNavigationBar(form: rawForm)
                    
                    let form = XLFormDescriptor(title: self.title)
                    var errored = false
                    SwiftTryCatch.try({
                        self.populateSections(form: form, rawForm: rawForm)
                    }, catch: { error in
                        os_log("Couldn't load remote form: %@", type: .error, error?.reason ?? "")
                        self.presentErrorDialog(message: String(localizationKey: "Unknown"), mustCancel: true)
                        errored = true
                    }, finally: {
                        
                    })
                        
                    if errored {
                        return
                    }
                    self.form = form
                    self.loadingView?.stopAnimating()
                } catch {
                    os_log("Couldn't load remote form: %@", type: .error, error.localizedDescription)
                    self.presentErrorDialog(message: String(localizationKey: "Unknown"), mustCancel: true)
                }
            }
        }
        task.resume()
    }
    
    private func presentErrorDialog(message: String, mustCancel: Bool) {
        let alert = UIAlertController(title: String(localizationKey: "Form_Error.Title", type: .error),
                                      message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: String(localizationKey: mustCancel ? "Cancel" : "OK"),
                                      style: .cancel, handler: { _ in
                                        if mustCancel {
                                            self.dismiss(animated: true, completion: nil)
                                        }
        }))
        self.present(alert, animated: true, completion: nil)
    }
    
    private func populateNavigationBar(form: [String: Any]) throws {
        if let title = form["title"] as? String {
            self.title = title
        } else {
            self.title = String(localizationKey: "Untitled_Form")
        }
        
        if let action = form["action"] as? String {
            let actionURL = URL(string: action)
            if !(actionURL?.isSecure ?? false) {
                return
            }
            
            formAction = action
            if let confirmButtonText = form["confirmButtonText"] as? String {
                submitBarButtonItem = UIBarButtonItem(title: confirmButtonText,
                                                      style: .done,
                                                      target: self,
                                                      action: #selector(DepictionFormViewController.submit(_:)))
            } else {
                submitBarButtonItem = UIBarButtonItem(barButtonSystemItem: .done,
                                                      target: self,
                                                      action: #selector(DepictionFormViewController.submit(_:)))
            }
            self.navigationItem.rightBarButtonItem = submitBarButtonItem
            
            if URL(string: formAction)?.host?.lowercased() != formURL?.host?.lowercased() {
                throw DepictionFormError.hostOriginException
            }
        }
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        // This is a really ugly way to hijack and handle errors thrown by XLForm during loading due to invalid data.
        // Because XLForm sets the properties on cell loading, rather than when we assign them, we have to override the cell loading method and try-catch it.
        var cell = UITableViewCell()
        SwiftTryCatch.try({
            cell = super.tableView(tableView, cellForRowAt: indexPath)
        }, catch: { error in
            os_log("Couldn't load remote form: %@", type: .error, error?.reason ?? "")
            self.presentErrorDialog(message: String(), mustCancel: true)
            self.form = nil
            self.tableView.reloadData()
        }, finally: {
            
        })
        return cell
    }
    
    private func populateSections(form: XLFormDescriptor, rawForm: [String: Any]) {
        guard let sections = rawForm["sections"] as? [[String: Any]] else {
            return
        }
        
        for rawSection in sections {
            let title = rawSection["title"] as? String
            
            let rawOptions = rawSection["options"] as? NSNumber
            let options = XLFormSectionOptions(rawValue: rawOptions?.uintValue ?? 0)
            
            let rawInsertMode = rawSection["insertMode"] as? NSNumber
            guard let insertMode = XLFormSectionInsertMode(rawValue: rawInsertMode?.uintValue ?? 0) else {
                    continue
            }
            let section = XLFormSectionDescriptor.formSection(withTitle: title, sectionOptions: options, sectionInsertMode: insertMode)
            section.footerTitle = rawSection["footerTitle"] as? String
            section.multivaluedTag = rawSection["multivaluedTag"] as? String
            
            self.populateRows(section: section, rawSection: rawSection)
            
            form.addFormSection(section)
        }
    }
    
    private func populateRows(section: XLFormSectionDescriptor, rawSection: [String: Any]) {
        guard let rows = rawSection["rows"] as? [[String: Any]] else {
            return
        }
        for rawRow in rows {
            let tag = rawRow["tag"] as? String
            guard let rowType = rawRow["rowType"] as? String else {
                continue
            }
            let title = rawRow["title"] as? String
            
            let row = XLFormRowDescriptor(tag: tag, rowType: rowType, title: title)
            if let value = rawRow["value"] {
                SwiftTryCatch.try({
                    row.value = value
                }, catch: { _ in
                }, finally: {
                    
                })
            }
            
            if let cellConfigs = rawRow["cellConfigs"] as? [String: Any] {
                for (key, val) in cellConfigs {
                    row.cellConfig[key] = val
                }
            }
            
            section.addFormRow(row)
        }
    }
    
    @objc private func dismiss(_ : Any?) {
        self.dismiss(animated: true, completion: nil)
    }
    
    @objc private func submit(_ : Any?) {
        self.tableView.isUserInteractionEnabled = false
        
        let submittingView = UIActivityIndicatorView(style: .gray)
        submittingView.startAnimating()
        self.navigationItem.rightBarButtonItem = UIBarButtonItem(customView: submittingView)
        
        guard var formValues = self.form.formValues() as? [String: Any] else {
            return
        }
        formValues["udid"] = UIDevice.current.uniqueIdentifier
        formValues["device"] = UIDevice.current.platform
        
        let provider = PaymentManager.shared.getPaymentProvider(for: formAction)
        if let provider = provider,
            provider.isAuthenticated {
            formValues["token"] = provider.authenticationToken
        }
        
        AF.request(formAction, method: .post, parameters: formValues, encoding: JSONEncoding.default)
            .responseJSON { response in
                self.tableView.isUserInteractionEnabled = true
                self.navigationItem.rightBarButtonItem = self.submitBarButtonItem
                
                print("Response: \(response)")
                switch response.result {
                case .success(let data):
                    print("Data: \(data)")
                    guard let responseObject = data as? [String: Any],
                        let success = responseObject["success"] as? Bool else {
                            self.presentErrorDialog(message: "An error occurred while submitting the form.", mustCancel: true)
                        return
                    }
                    let title = responseObject["title"] as? String
                    let message = responseObject["message"] as? String
                    
                    let fallbackTitle = success ? String(localizationKey: "Form_Submitted.Default_Title") :
                        String(localizationKey: "Form_Submit_Error.Title", type: .error)
                    let fallbackMessage = success ? String(localizationKey: "Form_Submitted.Default_Body") :
                        String(localizationKey: "Unknown", type: .error)
                    
                    let alert = UIAlertController(title: title ?? fallbackTitle,
                                                  message: message ?? fallbackMessage,
                                                  preferredStyle: .alert)
                    alert.addAction(UIAlertAction(title: "OK", style: .cancel, handler: { _ in
                        if success {
                            self.dismiss(animated: true, completion: nil)
                        }
                    }))
                    self.present(alert, animated: true, completion: nil)
                case .failure(let error):
                    self.presentErrorDialog(message: String(format: String(localizationKey: "Form_Submit_Failure"), error.localizedDescription),
                                            mustCancel: true)
                }
            }
    }
}
