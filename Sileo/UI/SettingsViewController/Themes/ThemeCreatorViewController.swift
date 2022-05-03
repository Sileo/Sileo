//
//  ThemeCreatorViewController.swift
//  Sileo
//
//  Created by Serena on 02/05/2022
//
	

import Foundation
import Alderis

fileprivate let defaultTheme = SileoThemeManager.shared.themeList.first(where: { $0.name == String(localizationKey: "Sileo_Adaptive") } )
class ThemeCreatorViewController: BaseSettingsViewController {
    var themeName: String? {
        let name = nameAlert.textFields?[safe: 0]?.text
        if name?.isEmpty ?? true {
            return nil
        }
        
        return name
    }
    
    var currentThemeComponentSelection: ThemeComponents? = nil // gets set, but only later
    
    // Contains the colors, the below are the defaults
    // they get set later
    var dict: [ThemeComponents: UIColor?] = [
        .backgroundColor: defaultTheme?.backgroundColor,
        .secondaryBgColor: defaultTheme?.secondaryBackgroundColor,
        .bannerColor: defaultTheme?.bannerColor,
        .headerColor: defaultTheme?.headerColor,
        .labelColor: defaultTheme?.labelColor,
        .highlightColor: defaultTheme?.highlightColor,
        .seperatorColor: defaultTheme?.seperatorColor
    ]
    
    var colorDictMapped: [ThemeComponents: UIColor] {
        dict.compactMapValues { $0 }
    }
    
    var nameAlert: UIAlertController = {
        let alert = UIAlertController(title: "Theme name", message: nil, preferredStyle: .alert)
        alert.addTextField { field in
            field.placeholder = "name"
        }
        alert.addAction(.init(title: "Set", style: .cancel, handler: nil))
        return alert
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        navigationItem.title = String(localizationKey: "Create_Theme")
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if section == 0 || section == 2 {
            return 1
        }
        
        return 7
    }
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        3
    }
    
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if indexPath.section == 0 {
            let cell = tableView.dequeueReusableCell(withIdentifier: "ThemeCreatorCell") ?? UITableViewCell(style: .default, reuseIdentifier: "ThemeCreatorCell")
            if let themeName = themeName {
                cell.textLabel?.text = "Name: \(themeName)"
            } else {
                cell.textLabel?.text = "Set name"
            }
            
            cell.backgroundColor = .clear
            return cell
        } else if indexPath.section == 2 {
            let cell = UITableViewCell(style: .default, reuseIdentifier: "ThemeCreatorCell")
            cell.textLabel?.text = String(localizationKey: "Create_Theme")
            cell.backgroundColor = .clear
            return cell
        }
        
        let rowComponent = ThemeComponents(rawValue: indexPath.row) ?? .highlightColor
        switch indexPath.row {
        case 0:
            let cell = SettingsColorTableViewCell(style: .default, reuseIdentifier: "ColorPickerCell")
            cell.textLabel?.text = String(localizationKey: "Background_Color")
            cell.bgClr = colorDictMapped[rowComponent]
            
            return cell
        case 1:
            let cell = SettingsColorTableViewCell(style: .default, reuseIdentifier: "ColorPickerCell")
            cell.textLabel?.text = String(localizationKey: "Secondary_Background_Color")
            cell.bgClr = colorDictMapped[rowComponent]
            
            return cell
        case 2:
            let cell = SettingsColorTableViewCell(style: .default, reuseIdentifier: "ColorPickerCell")
            cell.textLabel?.text = String(localizationKey: "Label_Color")
            cell.bgClr = colorDictMapped[rowComponent]
            
            return cell
        case 3:
            let cell = SettingsColorTableViewCell(style: .default, reuseIdentifier: "ColorPickerCell")
            cell.textLabel?.text = String(localizationKey: "Highlight_Color")
            cell.bgClr = colorDictMapped[rowComponent]
            
            return cell
        case 4:
            let cell = SettingsColorTableViewCell(style: .default, reuseIdentifier: "ColorPickerCell")
            cell.textLabel?.text = String(localizationKey: "Seperator_Color")
            cell.bgClr = colorDictMapped[rowComponent]
            
            return cell
        case 5:
            let cell = SettingsColorTableViewCell(style: .default, reuseIdentifier: "ColorPickerCell")
            cell.textLabel?.text = String(localizationKey: "Header_Color")
            cell.bgClr = colorDictMapped[rowComponent]
            
            return cell
        case 6:
            let cell = SettingsColorTableViewCell(style: .default, reuseIdentifier: "ColorPickerCell")
            cell.textLabel?.text = String(localizationKey: "Banner_Color")
            cell.bgClr = colorDictMapped[rowComponent]
            
            return cell
            
        default: fatalError("What have you done?!, we got row: \(indexPath.row)")
        }
    }
    
    var sectionVC: ThemesSectionViewController? = nil
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        switch indexPath.section {
        case 0:
            self.present(nameAlert, animated: true, completion: nil)
        case 1:
            currentThemeComponentSelection = .init(rawValue: indexPath.row)
            print("presenting color controller..")
            presentColorController()
        case 2:
            guard let themeName = themeName else {
                let controller = UIAlertController(title: "Please set a name.", message: nil, preferredStyle: .alert)
                controller.addAction(.init(title: "OK", style: .cancel))
                return
            }
            
            guard !SileoThemeManager.shared.themeList.map({ $0.name }).contains(themeName) else {
                let controller = UIAlertController(title: "Cannot use name", message: "The name \"\(themeName)\" is already being used", preferredStyle: .alert)
                controller.addAction(.init(title: "OK", style: .cancel, handler: nil))
                self.present(controller, animated: true, completion: nil)
                return
            }
            print("theme name: \(themeName)")
            
            let themeInstance = SileoTheme(name: themeName, interfaceStyle: .system)
            let compactDict = dict.compactMapValues { $0 }
            
            themeInstance.backgroundColor = compactDict[.backgroundColor]
            themeInstance.secondaryBackgroundColor = compactDict[.secondaryBgColor]
            themeInstance.seperatorColor = compactDict[.seperatorColor]
            themeInstance.highlightColor = compactDict[.highlightColor]
            themeInstance.labelColor = compactDict[.labelColor]
            themeInstance.bannerColor = compactDict[.bannerColor]
            themeInstance.headerColor = compactDict[.headerColor]
            let userSavedThemesData = UserDefaults.standard.data(forKey: "userSavedThemes") ?? Data()
            var themes = (try? JSONDecoder().decode([SileoCodableTheme].self, from: userSavedThemesData)) ?? []
            themes.append(themeInstance.codable)
            guard let encoded = try? JSONEncoder().encode(themes) else {
                print("couldn't encode themes.")
                print("themes: \(themes)")
                return
            }
            
            UserDefaults.standard.set(encoded, forKey: "userSavedThemes")
            print("themes should now be: \(themes)")
            sectionVC?.tableView.reloadData()
            self.navigationController?.popViewController(animated: true)
        default: break
        }
    }
    
    func presentColorController() {
        if #available(iOS 14, *) {
            let colorPickerViewController = UIColorPickerViewController()
            colorPickerViewController.delegate = self
            colorPickerViewController.supportsAlpha = false
            colorPickerViewController.selectedColor = .tintColor
            self.present(colorPickerViewController, animated: true)
        } else {
            let colorPickerViewController = ColorPickerViewController()
            colorPickerViewController.delegate = self
            colorPickerViewController.configuration = ColorPickerConfiguration(color: .tintColor)
            if UIDevice.current.userInterfaceIdiom == .pad {
                if #available(iOS 13, *) {
                    colorPickerViewController.popoverPresentationController?.sourceView = self.navigationController?.view
                }
            }
            colorPickerViewController.modalPresentationStyle = .overFullScreen
            self.parent?.present(colorPickerViewController, animated: true, completion: nil)
        }
    }
    
    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        switch section {
        case 0:
            return "Name"
        case 1:
            return "Colors"
        default: return nil
        }
    }
}

extension ThemeCreatorViewController: ColorPickerDelegate {
    func colorPicker(_ colorPicker: ColorPickerViewController, didSelect color: UIColor) {
        guard let selection = currentThemeComponentSelection else {
            print("selection is nil, we out.")
            return
        }
        
        dict[selection] = color
        tableView.reloadData()
    }
}

@available(iOS 14.0, *)
extension ThemeCreatorViewController: UIColorPickerViewControllerDelegate {
    func colorPickerViewControllerDidFinish(_ viewController: UIColorPickerViewController) {
        guard let selection = currentThemeComponentSelection else {
            print("selection is nil, we out.")
            return
        }
        dict[selection] = viewController.selectedColor
        tableView.reloadData()
    }
}

enum ThemeComponents: Int {
    case backgroundColor = 0
    case secondaryBgColor
    case labelColor
    case highlightColor
    case seperatorColor
    case headerColor
    case bannerColor
}
