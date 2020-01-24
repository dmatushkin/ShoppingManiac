//
//  ErrorExtension.swift
//  ShoppingManiac
//
//  Created by Dmitry Matyushkin on 1/24/20.
//  Copyright © 2020 Dmitry Matyushkin. All rights reserved.
//

import Foundation

extension Error {
    
    func showError(title: String) {
        AppDelegate.showAlert(title: title, message: self.localizedDescription)
    }
}
