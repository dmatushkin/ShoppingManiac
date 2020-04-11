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
import RxSwift

class GroupItem {
    let objectId: NSManagedObjectID
    let itemName: String
    let itemCategoryName: String?
    let itemQuantityString: String
    var purchased: Bool = false
    let isCrossListItem: Bool

    init(shoppingListItem: ShoppingListItem) {
        self.objectId = shoppingListItem.objectID
        self.itemName = shoppingListItem.good?.name ?? "No name"
        self.itemCategoryName = shoppingListItem.good?.category?.name
        self.itemQuantityString = shoppingListItem.quantityText
        self.purchased = shoppingListItem.purchased
        self.isCrossListItem = shoppingListItem.isCrossListItem
    }

    func lessThan(item: GroupItem) -> Bool {
        if self.purchased == item.purchased {
            return self.itemName < item.itemName
        } else {
            return (self.purchased ? 0 : 1) > (item.purchased ? 0 : 1)
        }
    }
}
