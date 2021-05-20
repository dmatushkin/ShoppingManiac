//
//  CategoryStoreOrder+CoreDataProperties.swift
//  ShoppingManiac
//
//  Created by Dmitry Matyushkin on 19.05.2021.
//  Copyright © 2021 Dmitry Matyushkin. All rights reserved.
//
//

import Foundation
import CoreData

extension CategoryStoreOrder {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<CategoryStoreOrder> {
        return NSFetchRequest<CategoryStoreOrder>(entityName: "CategoryStoreOrder")
    }

    @NSManaged public var order: Int64
    @NSManaged public var category: Category?
    @NSManaged public var store: Store?

}

extension CategoryStoreOrder: Identifiable {

}
