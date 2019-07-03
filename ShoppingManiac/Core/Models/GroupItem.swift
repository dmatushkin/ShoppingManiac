//
//  GroupItem.swift
//  ShoppingManiac
//
//  Created by Dmitry Matyushkin on 29/05/2017.
//  Copyright © 2017 Dmitry Matyushkin. All rights reserved.
//

import Foundation
import CoreData
import CoreStore

class GroupItem {
    let objectId: NSManagedObjectID
    let itemName: String
    let itemCategoryName: String?
    let itemQuantityString: String
    var purchased: Bool = false

    init(shoppingListItem: ShoppingListItem) {
        self.objectId = shoppingListItem.objectID
        self.itemName = shoppingListItem.good?.name ?? "No name"
        self.itemCategoryName = shoppingListItem.good?.category?.name
        self.itemQuantityString = shoppingListItem.quantityText
        self.purchased = shoppingListItem.purchased
    }

    func lessThan(item: GroupItem) -> Bool {
        if self.purchased == item.purchased {
            return self.itemName < item.itemName
        } else {
            return (self.purchased ? 0 : 1) > (item.purchased ? 0 : 1)
        }
    }
    
    func togglePurchased(list: ShoppingList) {
        self.purchased = !self.purchased
        try? CoreStore.perform(synchronous: {[weak self] transaction in
            guard let `self` = self else { return }
            if let shoppingListItem: ShoppingListItem = transaction.edit(Into<ShoppingListItem>(), self.objectId), let shoppingList: ShoppingList = transaction.edit(list) {
                shoppingListItem.purchased = self.purchased
                shoppingListItem.list = shoppingList
            }
        })
    }
    
    func markRemoved() {
        try? CoreStore.perform(synchronous: {[weak self] transaction in
            guard let `self` = self else { return }
            if let shoppingListItem: ShoppingListItem = transaction.edit(Into<ShoppingListItem>(), self.objectId) {
                shoppingListItem.isRemoved = true
            }
        })
    }
    
    func moveTo(group: ShoppingGroup) {
        try? CoreStore.perform(synchronous: {[weak self] transaction in
            guard let `self` = self else { return }
            if let shoppingListItem: ShoppingListItem = transaction.edit(Into<ShoppingListItem>(), self.objectId) {
                if let storeObjectId = group.objectId {
                    shoppingListItem.store = transaction.edit(Into<Store>(), storeObjectId)
                } else {
                    shoppingListItem.store = nil
                }
            }
        })
    }
}
