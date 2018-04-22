//
//  ShoppingListItemsWrapper.swift
//  ShoppingManiac
//
//  Created by Dmitry Matyushkin on 22/04/2018.
//  Copyright © 2018 Dmitry Matyushkin. All rights reserved.
//

import Foundation
import CloudKit

class ShoppingListItemsWrapper {
    
    let database: CKDatabase
    let shoppingList: ShoppingList
    let record: CKRecord
    let items: [CKRecord]

    init(database: CKDatabase, shoppingList: ShoppingList, record: CKRecord, items: [CKRecord]) {
        self.database = database
        self.shoppingList = shoppingList
        self.record = record
        self.items = items
    }
}
