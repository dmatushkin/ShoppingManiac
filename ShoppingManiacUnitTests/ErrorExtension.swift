//
//  ErrorExtension.swift
//  ShoppingManiacUnitTests
//
//  Created by Dmitry Matyushkin on 1/24/20.
//  Copyright © 2020 Dmitry Matyushkin. All rights reserved.
//

import Foundation

extension Error {
    
    func showError(title: String) {
        print("Error \(title)\n\(self.localizedDescription)")
    }
}
