//
//  UIView+FromNib.swift
//  Sileo
//
//  Created by Amy on 18/03/2021.
//  Copyright © 2021 CoolStar. All rights reserved.
//

import UIKit

extension UIView {
    class func fromNib<T: UIView>() -> T {
        (Bundle(for: T.self).loadNibNamed(String(describing: T.self), owner: nil, options: nil)![0] as? T)!
    }
}
