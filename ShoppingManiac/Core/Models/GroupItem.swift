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

struct GroupItem: Hashable {
    let objectId: NSManagedObjectID
    let itemName: String
    let itemCategoryName: String?
    let itemCategoryOrder: Int
    let itemQuantityString: String
    var purchased: Bool = false
    let isImportantItem: Bool

    init(shoppingListItem: ShoppingListItem) {
        self.objectId = shoppingListItem.objectID
        self.itemName = shoppingListItem.good?.name ?? "No name"
        self.itemCategoryName = shoppingListItem.good?.category?.name
        self.itemCategoryOrder = Int((shoppingListItem.store?.orders as? Set<CategoryStoreOrder>)?.first(where: { $0.category != nil && $0.category == shoppingListItem.good?.category })?.order ?? Int64.max)
        self.itemQuantityString = shoppingListItem.quantityText
        self.purchased = shoppingListItem.purchased
        self.isImportantItem = shoppingListItem.isImportant
    }

    func lessThan(item: GroupItem) -> Bool {
        if self.purchased == item.purchased {
			if self.itemCategoryOrder == item.itemCategoryOrder {
                if self.itemCategoryOrder == Int.max {
                    if self.itemCategoryName == item.itemCategoryName {
                        return self.itemName < item.itemName
                    } else {
                        return (self.itemCategoryName ?? "") < (item.itemCategoryName ?? "")
                    }
                } else {
                    return self.itemName < item.itemName
                }
			} else {
				return self.itemCategoryOrder < item.itemCategoryOrder
			}
        } else {
            return (self.purchased ? 0 : 1) > (item.purchased ? 0 : 1)
        }
    }
}
