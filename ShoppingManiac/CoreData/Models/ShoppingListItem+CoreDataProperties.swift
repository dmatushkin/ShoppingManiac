//
//  ShoppingListItem+CoreDataProperties.swift
//  ShoppingManiac
//
//  Created by Dmitry Matyushkin on 19.05.2021.
//  Copyright © 2021 Dmitry Matyushkin. All rights reserved.
//
//

import Foundation
import CoreData

extension ShoppingListItem {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<ShoppingListItem> {
        return NSFetchRequest<ShoppingListItem>(entityName: "ShoppingListItem")
    }

    @NSManaged public var comment: String?
    @NSManaged public var isImportant: Bool
    @NSManaged public var isRemoved: Bool
    @NSManaged public var isWeight: Bool
    @NSManaged public var price: Float
    @NSManaged public var purchased: Bool
    @NSManaged public var purchaseDate: TimeInterval
    @NSManaged public var quantity: Float
    @NSManaged public var recordid: String?
    @NSManaged public var good: Good?
    @NSManaged public var list: ShoppingList?
    @NSManaged public var store: Store?

}

extension ShoppingListItem: Identifiable {

}
