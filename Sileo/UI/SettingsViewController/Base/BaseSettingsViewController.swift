//
//  BaseSettingsViewController.swift
//  Sileo
//
//  Created by Skitty on 1/27/20.
//  Copyright © 2022 Sileo Team. All rights reserved.
//

import Foundation

class BaseSettingsViewController: UITableViewController {
    private var headerContainerView: SettingsHeaderContainerView = SettingsHeaderContainerView()
    
    var headerView: UIView {
        get {
            headerContainerView.headerView ?? UIView()
        }
        set {
            headerContainerView.headerView = newValue as? (UIView & SettingsHeaderViewDisplayable)
        }
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }
    
    override init(style: UITableView.Style) {
        super.init(style: style)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.layoutHeader()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.navigationItem.rightBarButtonItem = UIBarButtonItem(title: String(localizationKey: "Done_Editing"),
                                                                 style: .done,
                                                                 target: self,
                                                                 action: #selector(dismissController))
       
        self.view.addSubview(headerContainerView)
        headerContainerView.layer.zPosition = 1000
        
        self.view.backgroundColor = .white
        self.tableView.separatorColor = .clear
        
        self.tableView.backgroundColor = .sileoBackgroundColor
        
        weak var weakSelf = self
        NotificationCenter.default.addObserver(weakSelf as Any,
                                               selector: #selector(updateSileoColors),
                                               name: SileoThemeManager.sileoChangedThemeNotification,
                                               object: nil)
    }
    
    @objc func updateSileoColors() {
        self.tableView.backgroundColor = .sileoBackgroundColor
    }
    
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        if #available(iOS 13, *) {
            self.tableView.backgroundColor = .sileoBackgroundColor
        }
    }

    @objc func dismissController() {
        self.dismiss(animated: true)
    }
    
    func layoutHeader() {
        let contentHeight: CGFloat = headerContainerView.contentHeight(forWidth: self.view.bounds.size.width)
        let minDisplayHeight = self.view.safeAreaInsets.top
        let maxDisplayHeight = minDisplayHeight + contentHeight
        
        let pastTop: CGFloat = fmax(0, self.tableView.contentOffset.y + minDisplayHeight)
        let yPos: CGFloat = fmin(-maxDisplayHeight, self.tableView.contentOffset.y) + pastTop
        let elasticHeight: CGFloat = fmax(0, -self.tableView.contentOffset.y - maxDisplayHeight)
        
        headerContainerView.frame = CGRect(x: 0, y: yPos, width: self.view.bounds.size.width, height: maxDisplayHeight + elasticHeight)
        headerContainerView.elasticHeight = elasticHeight
        self.tableView.contentInset = UIEdgeInsets(top: contentHeight, left: 0, bottom: 0, right: 0)
        
        if (headerContainerView.headerView) != nil {
            let topPart = self.tableView.contentOffset.y + self.tableView.adjustedContentInset.top
            let compactProgress = topPart / contentHeight
            self.setTitleViewAlpha((compactProgress / 0.6) - 0.6)
            headerContainerView.headerView?.alpha = 1 - (compactProgress / 0.4)
        } else {
            self.setTitleViewAlpha(1)
        }
    }

    func setTitleViewAlpha(_ alpha: CGFloat) {
        let titleColor = SileoThemeManager.shared.currentTheme.labelColor ?? UIColor.black
        let titleColorWithAlpha = titleColor.withAlphaComponent(alpha)
        let titleAttributes = [NSAttributedString.Key.foregroundColor: titleColorWithAlpha as Any]
        self.navigationController?.navigationBar.titleTextAttributes = titleAttributes
    }
}

extension BaseSettingsViewController { // Subclass Convenience
    func reusableCell(withStyle style: UITableViewCell.CellStyle, reuseIdentifier: String) -> UITableViewCell {
        self.reusableCell(withStyle: style, reuseIdentifier: reuseIdentifier, cellClass: UITableViewCell.self)
    }

    func reusableCell(withStyle style: UITableViewCell.CellStyle, reuseIdentifier: String, cellClass: AnyClass) -> UITableViewCell {
        var cell: UITableViewCell? = self.tableView.dequeueReusableCell(withIdentifier: reuseIdentifier)
        if cell == nil {
            let myClass = cellClass as? UITableViewCell.Type ?? UITableViewCell.self
            cell = myClass.init(style: style, reuseIdentifier: reuseIdentifier)
            cell?.selectionStyle = UITableViewCell.SelectionStyle.gray
            cell?.selectedBackgroundView = SileoSelectionView(frame: CGRect.zero)
        }
        cell?.backgroundColor = UIColor.clear
        return cell ?? UITableViewCell()
    }
}

extension BaseSettingsViewController { // Scroll View Delegate
    override func scrollViewDidScroll(_ scrollView: UIScrollView) {
        self.layoutHeader()
    }
}

extension BaseSettingsViewController { // Data Source Overrides
    override func tableView(_ tableView: UITableView, viewForHeaderInSection section: NSInteger) -> UIView? {
        let title: String? = self.tableView(tableView, titleForHeaderInSection: section)
        if title == nil {
            return nil
        }
        
        let labelContainer: UIView = UIView()
        labelContainer.preservesSuperviewLayoutMargins = true
        labelContainer.insetsLayoutMarginsFromSafeArea = true
        labelContainer.layoutMargins = UIEdgeInsets(top: 16,
                                                    left: labelContainer.layoutMargins.left,
                                                    bottom: 8,
                                                    right: labelContainer.layoutMargins.right)
        
        let label: UILabel = SileoLabelView()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.text = title
        label.font = UIFont.systemFont(ofSize: 19, weight: .semibold)
        
        labelContainer.addSubview(label)
        label.topAnchor.constraint(equalTo: labelContainer.layoutMarginsGuide.topAnchor).isActive = true
        label.bottomAnchor.constraint(equalTo: labelContainer.layoutMarginsGuide.bottomAnchor).isActive = true
        label.leftAnchor.constraint(equalTo: labelContainer.layoutMarginsGuide.leftAnchor).isActive = true
        label.rightAnchor.constraint(equalTo: labelContainer.layoutMarginsGuide.rightAnchor).isActive = true
        
        return labelContainer
    }
}

extension BaseSettingsViewController { // Table View Delegate Overrides
    override func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        cell.textLabel?.textColor = cell.tintColor
        cell.detailTextLabel?.textColor = cell.tintColor
    }
}
