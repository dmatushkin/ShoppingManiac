//
//  ShoppingListWrapper.swift
//  ShoppingManiac
//
//  Created by Dmitry Matyushkin on 22/04/2018.
//  Copyright © 2018 Dmitry Matyushkin. All rights reserved.
//

import Foundation
import CloudKit

class ShoppingListWrapper {
    let database: CKDatabase
    let record: CKRecord
    let shoppingList: ShoppingList
    let items: [CKReference]
    
    init(database: CKDatabase, record: CKRecord, shoppingList: ShoppingList, items: [CKReference]) {
        self.database = database
        self.record = record
        self.shoppingList = shoppingList
        self.items = items
    }
}
