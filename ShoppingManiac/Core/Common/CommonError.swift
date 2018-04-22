//
//  CommonError.swift
//  ShoppingManiac
//
//  Created by Dmitry Matyushkin on 22/04/2018.
//  Copyright © 2018 Dmitry Matyushkin. All rights reserved.
//

import Foundation

class CommonError: LocalizedError {
    
    private let description: String
    
    init(description: String) {
        self.description = description
    }
    
    var errorDescription: String? {
        return self.description
    }
}
