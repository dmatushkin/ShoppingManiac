//
//  GoodRating+CoreDataProperties.swift
//  ShoppingManiac
//
//  Created by Dmitry Matyushkin on 9/14/19.
//  Copyright © 2019 Dmitry Matyushkin. All rights reserved.
//
//

import Foundation
import CoreData

extension GoodRating {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<GoodRating> {
        return NSFetchRequest<GoodRating>(entityName: "GoodRating")
    }

    @NSManaged public var date: TimeInterval
    @NSManaged public var rating: Int16
    @NSManaged public var good: Good?

}
