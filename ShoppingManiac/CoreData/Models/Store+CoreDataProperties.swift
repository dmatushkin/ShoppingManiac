//
//  Store+CoreDataProperties.swift
//  ShoppingManiac
//
//  Created by Dmitry Matyushkin on 21/05/2017.
//  Copyright © 2017 Dmitry Matyushkin. All rights reserved.
//

import Foundation
import CoreData

extension Store {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<Store> {
        return NSFetchRequest<Store>(entityName: "Store")
    }

    @NSManaged public var name: String?
    @NSManaged public var recordid: String?
    @NSManaged public var items: NSSet?

}

// MARK: Generated accessors for items
extension Store {

    @objc(addItemsObject:)
    @NSManaged public func addToItems(_ value: ShoppingListItem)

    @objc(removeItemsObject:)
    @NSManaged public func removeFromItems(_ value: ShoppingListItem)

    @objc(addItems:)
    @NSManaged public func addToItems(_ values: NSSet)

    @objc(removeItems:)
    @NSManaged public func removeFromItems(_ values: NSSet)

}
