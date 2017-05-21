//
//  Category+CoreDataProperties.swift
//  ShoppingManiac
//
//  Created by Dmitry Matyushkin on 21/05/2017.
//  Copyright © 2017 Dmitry Matyushkin. All rights reserved.
//

import Foundation
import CoreData


extension Category {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<Category> {
        return NSFetchRequest<Category>(entityName: "Category")
    }

    @NSManaged public var name: String?
    @NSManaged public var recordid: String?
    @NSManaged public var children: NSSet?
    @NSManaged public var goods: NSSet?
    @NSManaged public var parent: Category?

}

// MARK: Generated accessors for children
extension Category {

    @objc(addChildrenObject:)
    @NSManaged public func addToChildren(_ value: Category)

    @objc(removeChildrenObject:)
    @NSManaged public func removeFromChildren(_ value: Category)

    @objc(addChildren:)
    @NSManaged public func addToChildren(_ values: NSSet)

    @objc(removeChildren:)
    @NSManaged public func removeFromChildren(_ values: NSSet)

}

// MARK: Generated accessors for goods
extension Category {

    @objc(addGoodsObject:)
    @NSManaged public func addToGoods(_ value: Good)

    @objc(removeGoodsObject:)
    @NSManaged public func removeFromGoods(_ value: Good)

    @objc(addGoods:)
    @NSManaged public func addToGoods(_ values: NSSet)

    @objc(removeGoods:)
    @NSManaged public func removeFromGoods(_ values: NSSet)

}
