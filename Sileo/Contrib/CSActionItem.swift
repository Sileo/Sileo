//
//  CSActionItem.swift
//  Sileo
//
//  Created by CoolStar on 12/9/20.
//  Copyright © 2022 Sileo Team. All rights reserved.
//

import Foundation

extension UIImage {
    public convenience init?(systemNameOrNil name: String) {
        if #available(iOS 13.0, *) {
            self.init(systemName: name)
        } else {
            return nil
        }
    }
}

class CSActionItem {
    let title: String
    let image: UIImage?
    let style: UIPreviewAction.Style
    let handler: () -> Void
    
    init(title: String, image: UIImage? = nil, style: UIPreviewAction.Style = .default, handler: @escaping () -> Void) {
        self.title = title
        self.image = image
        self.style = style
        self.handler = handler
    }
    
    func previewAction() -> UIPreviewAction {
        UIPreviewAction(title: title, style: style) { _, _ in
            self.handler()
        }
    }
    
    @available(iOS 13.0, *)
    var menuStyle: UIMenuElement.Attributes {
        switch style {
        case .default:
            return []
        case .destructive:
            return .destructive
        default:
            return []
        }
    }
    
    @available(iOS 13.0, *)
    func action() -> UIAction {
        UIAction(title: title, image: image, attributes: self.menuStyle) { _ in
            self.handler()
        }
    }
}
