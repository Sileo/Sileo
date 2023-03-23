//
//  ThemesSectionViewController.swift
//  Sileo
//
//  Created by Serena on 02/05/2022
//
	

import Foundation
import ZippyJSON

class ThemesSectionViewController: BaseSettingsViewController {
    
    var settingsSender: SettingsViewController?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        navigationItem.rightBarButtonItem = .init(barButtonSystemItem: .add, target: self, action: #selector(promptController))
        navigationItem.title = String(localizationKey: "Manage_Themes")
    }
    
    func importThemes(fromURL url: URL) {
        do {
            let data = try Data(contentsOf: url)
            let decoded = try ZippyJSONDecoder().decode([SileoCodableTheme].self, from: data)
            userThemes.append(contentsOf: decoded.map(\.sileoTheme))
            tableView?.reloadData()
            print("Imported theme(s)")
        } catch {
            let controller = UIAlertController(title: String(localizationKey: "Couldnt_Import_Themes", type: .error), message: "Error: \(error.localizedDescription)", preferredStyle: .alert)
            self.present(controller, animated: true, completion: nil)
        }
        
    }
    
    func exportThemes(_ themes: [SileoCodableTheme]) {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        
        guard let encoded = try? JSONEncoder().encode(themes), let themesString = String(data: encoded, encoding: .utf8) else { return }

        let activityVC = UIActivityViewController(activityItems: [themesString], applicationActivities: nil)
        activityVC.popoverPresentationController?.sourceView = self.view
        activityVC.popoverPresentationController?.sourceRect = CGRect(x: self.view.bounds.midX, y: self.view.bounds.midY, width: 0, height: 0)

        self.present(activityVC, animated: true, completion: nil)
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
            self.exportThemes(self.userThemes.map(\.codable))
        }))
        
        
        controller.addAction(.init(title: String(localizationKey: "Cancel"), style: .cancel, handler: { _ in
            controller.dismiss(animated: true, completion: nil)
        }))
        
        self.present(controller, animated: true)
    }
    
    var userThemes: [SileoTheme] {
        get {
            let data = UserDefaults.standard.data(forKey: "userSavedThemes") ?? Data()
            return ((try? ZippyJSONDecoder().decode([SileoCodableTheme].self, from: data)) ?? []).map { $0.sileoTheme }
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
            self.settingsSender?.tableView.reloadData()
            handler(true)
        }
        removeAction.image = UIImage(systemNameOrNil: "trash")
        
        let exportAction = UIContextualAction(style: .normal, title: String(localizationKey: "Export")) { _, _, handler in
            self.exportThemes([self.userThemes[indexPath.row].codable])
            handler(true)
        }
        exportAction.backgroundColor = .systemBlue
        exportAction.image = UIImage(systemNameOrNil: "square.and.arrow.up")
        
        return UISwipeActionsConfiguration(actions: [removeAction, exportAction])
    }
    
    
    class ThemesImporterDelegate: NSObject, UIDocumentPickerDelegate {
        var parent: ThemesSectionViewController? = nil
        
        static let shared = ThemesImporterDelegate()
        
        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            guard let firstURL = urls.first else {
                print("couldn't access URL. rip")
                return
            }
            
            parent?.importThemes(fromURL: firstURL)
        }
    }
}
