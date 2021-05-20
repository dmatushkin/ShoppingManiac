//
//  Good+CoreDataProperties.swift
//  ShoppingManiac
//
//  Created by Dmitry Matyushkin on 19.05.2021.
//  Copyright © 2021 Dmitry Matyushkin. All rights reserved.
//
//

import Foundation
import CoreData

extension Good {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<Good> {
        return NSFetchRequest<Good>(entityName: "Good")
    }

    @NSManaged public var name: String?
    @NSManaged public var personalRating: Int16
    @NSManaged public var recordid: String?
    @NSManaged public var category: Category?
    @NSManaged public var items: NSSet?
    @NSManaged public var pictures: NSSet?
    @NSManaged public var ratings: NSSet?

}

// MARK: Generated accessors for items
extension Good {

    @objc(addItemsObject:)
    @NSManaged public func addToItems(_ value: ShoppingListItem)

    @objc(removeItemsObject:)
    @NSManaged public func removeFromItems(_ value: ShoppingListItem)

    @objc(addItems:)
    @NSManaged public func addToItems(_ values: NSSet)

    @objc(removeItems:)
    @NSManaged public func removeFromItems(_ values: NSSet)

}

// MARK: Generated accessors for pictures
extension Good {

    @objc(addPicturesObject:)
    @NSManaged public func addToPictures(_ value: Picture)

    @objc(removePicturesObject:)
    @NSManaged public func removeFromPictures(_ value: Picture)

    @objc(addPictures:)
    @NSManaged public func addToPictures(_ values: NSSet)

    @objc(removePictures:)
    @NSManaged public func removeFromPictures(_ values: NSSet)

}

// MARK: Generated accessors for ratings
extension Good {

    @objc(addRatingsObject:)
    @NSManaged public func addToRatings(_ value: GoodRating)

    @objc(removeRatingsObject:)
    @NSManaged public func removeFromRatings(_ value: GoodRating)

    @objc(addRatings:)
    @NSManaged public func addToRatings(_ values: NSSet)

    @objc(removeRatings:)
    @NSManaged public func removeFromRatings(_ values: NSSet)

}

extension Good: Identifiable {

}
