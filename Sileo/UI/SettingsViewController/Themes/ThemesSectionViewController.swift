//
//  ThemesSectionViewController.swift
//  Sileo
//
//  Created by Serena on 02/05/2022
//
	

import Foundation

class ThemesSectionViewController: BaseSettingsViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        
        navigationItem.rightBarButtonItem = .init(barButtonSystemItem: .add, target: self, action: #selector(promptController))
        navigationItem.title = String(localizationKey: "Manage_Themes")
    }
    
    @objc
    func promptController() {
        let controller = UIAlertController(title: "Add Theme", message: nil, preferredStyle: .actionSheet)
        controller.addAction(.init(title: String(localizationKey: "Create_Theme"), style: .default, handler: { _ in
            let creatorVC = ThemeCreatorViewController(style: .grouped)
            creatorVC.sectionVC = self
            self.navigationController?.pushViewController(creatorVC, animated: true)
        }))
        
        controller.addAction(.init(title: String(localizationKey: "Import_Themes"), style: .default, handler: { _ in
            let docPicker: UIDocumentPickerViewController
            if #available(iOS 14.0, *) {
                docPicker = UIDocumentPickerViewController(forOpeningContentTypes: [.item], asCopy: true)
            } else {
                docPicker = UIDocumentPickerViewController(documentTypes: ["public.item"], in: .open)
            }
            
            let delegate = ThemesImporterDelegate.shared
            delegate.parent = self
            docPicker.delegate = delegate
            self.present(docPicker, animated: true)
        }))
        
        controller.addAction(.init(title: String(localizationKey: "Export_Themes"), style: .default, handler: { _ in
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            guard let encoded = try? encoder.encode(self.userThemes.map(\.codable)), let stringThemes = String(data: encoded, encoding: .utf8) else {
                print("Couldn't encode and convert themes to string. we out.")
                return
            }
            let activityVC = UIActivityViewController(activityItems: [stringThemes], applicationActivities: nil)

            activityVC.popoverPresentationController?.sourceView = self.view
            activityVC.popoverPresentationController?.sourceRect = CGRect(x: self.view.bounds.midX, y: self.view.bounds.midY, width: 0, height: 0)

            self.present(activityVC, animated: true, completion: nil)
        }))
        
        
        controller.addAction(.init(title: String(localizationKey: "Cancel"), style: .cancel, handler: { _ in
            controller.dismiss(animated: true, completion: nil)
        }))
        
        self.present(controller, animated: true)
    }
    
    var userThemes: [SileoTheme] {
        get {
            let data = UserDefaults.standard.data(forKey: "userSavedThemes") ?? Data()
            return ((try? JSONDecoder().decode([SileoCodableTheme].self, from: data)) ?? []).map { $0.sileoTheme }
        } set {
            let encoded = (try? JSONEncoder().encode(newValue.map(\.codable))) ?? Data()
            UserDefaults.standard.set(encoded, forKey: "userSavedThemes")
        }
    }
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        userThemes.count
    }
    
    override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        return true
    }
    
    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return "Themes"
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = UITableViewCell(style: .default, reuseIdentifier: "ThemesCell")
        cell.textLabel?.text = userThemes[safe: indexPath.row]?.name
        return cell
    }
    
    override func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {

        let removeAction = UIContextualAction(style: .destructive, title: "Remove") { _, _, handler in
            print("Removing \(self.userThemes[indexPath.row].name)")
            self.userThemes.remove(at: indexPath.row)
            tableView.deleteRows(at: [indexPath], with: .fade)
            handler(true)
        }
        
        return UISwipeActionsConfiguration(actions: [removeAction])
    }
    
    
    class ThemesImporterDelegate: NSObject, UIDocumentPickerDelegate {
        var parent: ThemesSectionViewController? = nil
        
        static let shared = ThemesImporterDelegate()
        
        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            print("URLs: \(urls)")
            guard let firstURL = urls.first, let data = try? Data(contentsOf: firstURL) else {
                print("couldn't access firstURL or data. rip")
                return
            }
            
            do {
                let decoded = try JSONDecoder().decode([SileoCodableTheme].self, from: data)
                parent?.userThemes.append(contentsOf: decoded.map(\.sileoTheme))
                parent?.tableView?.reloadData()
                print("imported themes")
            } catch {
                print("Failed to import themes from JSON. error: \(error)")
                let controller = UIAlertController(title: "Error while importing Themes: \(error)", message: nil, preferredStyle: .alert)
                controller.addAction(.init(title: "OK", style: .cancel, handler: nil))
                parent?.present(controller, animated: true, completion: nil)
                parent?.tableView?.reloadData()
            }
        }
    }
}
