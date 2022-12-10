//
//  EditableTableView.swift
//  Sileo
//
//  Created by CoolStar on 8/3/19.
//  Copyright © 2022 Sileo Team. All rights reserved.
//

import Evander
import UIKit

class EditableTableView: UITableView {
    override var isEditing: Bool {
        get {
            super.isEditing
        }
        // swiftlint:disable:next unused_setter_value
        set {
            super.isEditing = true
        }
    }
    
    override func setEditing(_ editing: Bool, animated: Bool) {
        Thread.mainBlock {
            super.setEditing(true, animated: animated)
        }
    }
    
    override func accessibilityPerformEscape() -> Bool {
        false
    }
}
