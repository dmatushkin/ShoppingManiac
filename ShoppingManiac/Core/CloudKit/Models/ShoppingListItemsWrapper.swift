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
    
    let localDb: Bool
    let shoppingList: ShoppingList
    let record: CKRecord
    let items: [CKRecord]
    let ownerName: String?

    init(localDb: Bool, shoppingList: ShoppingList, record: CKRecord, items: [CKRecord], ownerName: String?) {
        self.localDb = localDb
        self.shoppingList = shoppingList
        self.record = record
        self.items = items
        self.ownerName = ownerName
    }
}
