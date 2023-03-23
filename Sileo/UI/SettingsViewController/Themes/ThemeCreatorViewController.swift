//
//  ThemeCreatorViewController.swift
//  Sileo
//
//  Created by Serena on 02/05/2022
//
	

import Foundation
import Alderis
import ZippyJSON

fileprivate let defaultTheme = SileoThemeManager.shared.themeList.first
class ThemeCreatorViewController: BaseSettingsViewController {
    static let defaultComponents: [ThemeComponents: UIColor?] = [
        .backgroundColor: defaultTheme?.backgroundColor,
        .secondaryBgColor: defaultTheme?.secondaryBackgroundColor,
        .bannerColor: defaultTheme?.bannerColor,
        .headerColor: defaultTheme?.headerColor,
        .labelColor: defaultTheme?.labelColor,
        .highlightColor: defaultTheme?.highlightColor,
        .seperatorColor: defaultTheme?.seperatorColor
    ]
    
    var themeName: String? {
        guard let name = nameTextField.text, !name.isEmpty else {
            return nil
        }
        
        return name
    }
    
    var currentThemeComponentSelection: ThemeComponents? = nil // gets set, but only later
    var nameTextField: UITextField!
    
    // Contains the colors, the below are the defaults
    // they get set later
    var dict: [ThemeComponents: UIColor?] = ThemeCreatorViewController.defaultComponents
    
    var colorDictMapped: [ThemeComponents: UIColor] {
        dict.compactMapValues { $0 }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        nameTextField = UITextField()
        nameTextField.translatesAutoresizingMaskIntoConstraints = false
        nameTextField.placeholder = "name.."
        nameTextField.returnKeyType = .done
        nameTextField.addTarget(self, action: #selector(nameTextFieldDone), for: .primaryActionTriggered)
        navigationItem.title = String(localizationKey: "Create_Theme")
    }
    
    @objc func nameTextFieldDone() {
        nameTextField.resignFirstResponder()
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
            cell.textLabel?.text = "Theme Name"
            cell.contentView.addSubview(nameTextField)
            
            NSLayoutConstraint.activate([
                nameTextField.centerYAnchor.constraint(equalTo: cell.centerYAnchor),
                nameTextField.trailingAnchor.constraint(equalTo: cell.layoutMarginsGuide.trailingAnchor)
            ])
            
            cell.backgroundColor = .clear
            return cell
        } else if indexPath.section == 2 {
            let cell = UITableViewCell(style: .default, reuseIdentifier: "ThemeCreatorCell")
            cell.textLabel?.text = String(localizationKey: "Create_Theme")
            cell.backgroundColor = .clear
            return cell
        }
        
        let rowComponent = ThemeComponents(rawValue: indexPath.row) ?? .highlightColor
        let cell = SettingsColorTableViewCell(style: .default, reuseIdentifier: "ColorPickerCell")
        cell.bgClr = colorDictMapped[rowComponent]
        
        switch indexPath.row {
        case 0:
            cell.textLabel?.text = String(localizationKey: "Background_Color")
        case 1:
            cell.textLabel?.text = String(localizationKey: "Secondary_Background_Color")
        case 2:
            cell.textLabel?.text = String(localizationKey: "Label_Color")
        case 3:
            cell.textLabel?.text = String(localizationKey: "Highlight_Color")
        case 4:
            cell.textLabel?.text = String(localizationKey: "Seperator_Color")
        case 5:
            cell.textLabel?.text = String(localizationKey: "Header_Color")
        case 6:
            cell.textLabel?.text = String(localizationKey: "Banner_Color")
        default: fatalError("What have you done?!, we got row: \(indexPath.row)")
        }
        
        return cell
    }
    
    override func tableView(_ tableView: UITableView, viewForHeaderInSection section: NSInteger) -> UIView? {
        guard let original = super.tableView(tableView, viewForHeaderInSection: section) else {
            return nil
        }
        
        if section != 1 {
            return original
        }
        
        let resetButton = UIButton(type: .system)
        resetButton.setTitle("Reset", for: .normal)
        resetButton.translatesAutoresizingMaskIntoConstraints = false
        resetButton.addTarget(self, action: #selector(resetToDefaults), for: .touchUpInside)
        original.addSubview(resetButton)
        
        NSLayoutConstraint.activate([
            resetButton.centerYAnchor.constraint(equalTo: original.centerYAnchor),
            resetButton.trailingAnchor.constraint(equalTo: original.layoutMarginsGuide.trailingAnchor)
        ])
        return original
    }
    
    var sectionVC: ThemesSectionViewController? = nil
    
    @objc func resetToDefaults() {
        self.dict = ThemeCreatorViewController.defaultComponents
        tableView.reloadSections(IndexSet(integer: 1), with: .none)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }
    
    override func tableView(_ tableView: UITableView, shouldHighlightRowAt indexPath: IndexPath) -> Bool {
        return indexPath.section != 0
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        switch indexPath.section {
        case 1:
            currentThemeComponentSelection = .init(rawValue: indexPath.row)
            presentColorController()
            tableView.deselectRow(at: indexPath, animated: true)
        case 2:
            guard let themeName = themeName else {
                let controller = UIAlertController(title: "Please set a name.", message: nil, preferredStyle: .alert)
                controller.addAction(.init(title: "OK", style: .cancel))
                return
            }
            
            // make sure the name isn't already being used
            guard !SileoThemeManager.shared.themeList.contains(where: { $0.name == themeName }) else {
                let controller = UIAlertController(title: "Cannot use name", message: "The name \"\(themeName)\" is already being used", preferredStyle: .alert)
                controller.addAction(.init(title: "OK", style: .cancel, handler: nil))
                self.present(controller, animated: true, completion: nil)
                return
            }
            
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
            var themes = (try? ZippyJSONDecoder().decode([SileoCodableTheme].self, from: userSavedThemesData)) ?? []
            themes.append(themeInstance.codable)
            guard let encoded = try? JSONEncoder().encode(themes) else {
                return
            }
            
            UserDefaults.standard.set(encoded, forKey: "userSavedThemes")
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
            colorPickerViewController.popoverPresentationController?.sourceView = self.navigationController?.view
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
