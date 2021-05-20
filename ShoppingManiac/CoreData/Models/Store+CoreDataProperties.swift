//
//  Store+CoreDataProperties.swift
//  ShoppingManiac
//
//  Created by Dmitry Matyushkin on 19.05.2021.
//  Copyright © 2021 Dmitry Matyushkin. All rights reserved.
//
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
    @NSManaged public var orders: NSSet?

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

// MARK: Generated accessors for orders
extension Store {

    @objc(addOrdersObject:)
    @NSManaged public func addToOrders(_ value: CategoryStoreOrder)

    @objc(removeOrdersObject:)
    @NSManaged public func removeFromOrders(_ value: CategoryStoreOrder)

    @objc(addOrders:)
    @NSManaged public func addToOrders(_ values: NSSet)

    @objc(removeOrders:)
    @NSManaged public func removeFromOrders(_ values: NSSet)

}

extension Store: Identifiable {

}
