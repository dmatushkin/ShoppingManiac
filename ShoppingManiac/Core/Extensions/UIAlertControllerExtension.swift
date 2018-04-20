//
//  UIAlertControllerExtension.swift
//  ShoppingManiac
//
//  Created by Dmitry Matyushkin on 21/05/2017.
//  Copyright © 2017 Dmitry Matyushkin. All rights reserved.
//

import UIKit

extension UIAlertController {

    convenience init(title: String, message: String, confirmActionTitle: String, confirmAction : @escaping (() -> Void)) {
        self.init(title: title, message: message, preferredStyle: UIAlertControllerStyle.alert)
        self.addAction(UIAlertAction(title: "Cancel", style: UIAlertActionStyle.cancel) { _ in })
        self.addAction(UIAlertAction(title: confirmActionTitle, style: UIAlertActionStyle.destructive) { _ in
            confirmAction()
            }
        )
    }
}
