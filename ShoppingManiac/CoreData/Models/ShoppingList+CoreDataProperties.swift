//
//  ShoppingList+CoreDataProperties.swift
//  ShoppingManiac
//
//  Created by Dmitry Matyushkin on 19.05.2021.
//  Copyright © 2021 Dmitry Matyushkin. All rights reserved.
//
//

import Foundation
import CoreData

extension ShoppingList {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<ShoppingList> {
        return NSFetchRequest<ShoppingList>(entityName: "ShoppingList")
    }

    @NSManaged public var date: TimeInterval
    @NSManaged public var isRemote: Bool
    @NSManaged public var isRemoved: Bool
    @NSManaged public var name: String?
    @NSManaged public var ownerName: String?
    @NSManaged public var recordid: String?
    @NSManaged public var items: NSSet?

}

// MARK: Generated accessors for items
extension ShoppingList {

    @objc(addItemsObject:)
    @NSManaged public func addToItems(_ value: ShoppingListItem)

    @objc(removeItemsObject:)
    @NSManaged public func removeFromItems(_ value: ShoppingListItem)

    @objc(addItems:)
    @NSManaged public func addToItems(_ values: NSSet)

    @objc(removeItems:)
    @NSManaged public func removeFromItems(_ values: NSSet)

}

extension ShoppingList: Identifiable {

}
