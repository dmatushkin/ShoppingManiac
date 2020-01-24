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
    let localDb: Bool
    let record: CKRecord
    let shoppingList: ShoppingList
    let items: [CKRecord.Reference]
    let ownerName: String?
    
    init(localDb: Bool, record: CKRecord, shoppingList: ShoppingList, items: [CKRecord.Reference], ownerName: String?) {
        self.localDb = localDb
        self.record = record
        self.shoppingList = shoppingList
        self.items = items
        self.ownerName = ownerName
    }
}
