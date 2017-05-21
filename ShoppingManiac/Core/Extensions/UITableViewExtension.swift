//
//  UITableViewExtension.swift
//  ShoppingManiac
//
//  Created by Dmitry Matyushkin on 21/05/2017.
//  Copyright © 2017 Dmitry Matyushkin. All rights reserved.
//

import UIKit

extension UITableView {
    
    func dequeueCell<T:UITableViewCell>(indexPath: IndexPath) -> T? {
        return self.dequeueReusableCell(withIdentifier: String(describing: T.self), for: indexPath) as? T
    }
}
