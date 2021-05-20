//
//  StringExtension.swift
//  ShoppingManiac
//
//  Created by Dmitry Matyushkin on 19.05.2021.
//  Copyright © 2021 Dmitry Matyushkin. All rights reserved.
//

import Foundation

extension String {
    
    var nilIfEmpty: String? {
        guard !self.isEmpty else { return nil }
        return self
    }
}
