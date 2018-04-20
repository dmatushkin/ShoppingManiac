//
//  UITableViewExtension.swift
//  ShoppingManiac
//
//  Created by Dmitry Matyushkin on 21/05/2017.
//  Copyright © 2017 Dmitry Matyushkin. All rights reserved.
//

import UIKit

extension UITableView {

    func dequeueCell<T: UITableViewCell>(indexPath: IndexPath) -> T? {
        return self.dequeueReusableCell(withIdentifier: String(describing: T.self), for: indexPath) as? T
    }

    func setTopInset(inset: CGFloat) {
        var insets = self.contentInset
        insets.top = inset
        self.contentInset = insets
    }

    func setBottomInset(inset: CGFloat) {
        var insets = self.contentInset
        insets.bottom = inset
        self.contentInset = insets
    }

    func setSideInsets(left: CGFloat, right: CGFloat) {
        var insets = self.contentInset
        insets.left = left
        insets.right = right
        self.contentInset = insets
    }
}
