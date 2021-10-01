//
//  ThemePickerView.swift
//  Sileo
//
//  Created by Andromeda on 14/06/2021.
//  Copyright © 2021 Sileo Team. All rights reserved.
//

import UIKit

class ThemePickerCell: UITableViewCell, UIPickerViewDelegate, UIPickerViewDataSource {
    
    public var values = [String]()
    public var pickerView = UIPickerView()
    public var title = UILabel()
    public var subtitle = UILabel()
    public var separator = UIView()
    public weak var callback: ThemeSelected?

    private let standardHeight: CGFloat = 44.0 // The standard height of a UITableView
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        clipsToBounds = true
    
        title.translatesAutoresizingMaskIntoConstraints = false
        subtitle.translatesAutoresizingMaskIntoConstraints = false
        separator.translatesAutoresizingMaskIntoConstraints = false
        pickerView.translatesAutoresizingMaskIntoConstraints = false
        
        contentView.addSubview(title)
        contentView.addSubview(subtitle)
        contentView.addSubview(separator)
        contentView.addSubview(pickerView)
        
        title.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20).isActive = true
        title.topAnchor.constraint(equalTo: contentView.topAnchor).isActive = true
        subtitle.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20).isActive = true
        subtitle.topAnchor.constraint(equalTo: contentView.topAnchor).isActive = true
        title.heightAnchor.constraint(equalToConstant: standardHeight).isActive = true
        subtitle.heightAnchor.constraint(equalToConstant: standardHeight).isActive = true
        
        separator.heightAnchor.constraint(equalToConstant: 0.7).isActive = true
        separator.leadingAnchor.constraint(equalTo: contentView.leadingAnchor).isActive = true
        separator.trailingAnchor.constraint(equalTo: contentView.trailingAnchor).isActive = true
        separator.topAnchor.constraint(equalTo: title.bottomAnchor).isActive = true
        
        pickerView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor).isActive = true
        pickerView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor).isActive = true
        pickerView.topAnchor.constraint(equalTo: separator.bottomAnchor).isActive = true
        pickerView.heightAnchor.constraint(equalToConstant: 116).isActive = true

        pickerView.delegate = self
        pickerView.dataSource = self
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func numberOfComponents(in pickerView: UIPickerView) -> Int {
        1
    }
    
    func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        values.count
    }
    
    func pickerView(_ pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String? {
        values[row]
    }
    
    func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
        subtitle.text = values[row]
        callback?.themeSelected(row)
    }
}

protocol ThemeSelected: AnyObject {
    func themeSelected(_ index: Int)
}
