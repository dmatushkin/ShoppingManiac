//
//  CloudKitOperationsProtocol.swift
//  ShoppingManiac
//
//  Created by Dmitry Matyushkin on 1/24/20.
//  Copyright © 2020 Dmitry Matyushkin. All rights reserved.
//

import Foundation
import CloudKit

protocol CloudKitOperationsProtocol {
    func run(operation: CKDatabaseOperation, localDb: Bool)
}
