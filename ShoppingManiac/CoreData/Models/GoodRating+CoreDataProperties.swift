//
//  GoodRating+CoreDataProperties.swift
//  ShoppingManiac
//
//  Created by Dmitry Matyushkin on 19.05.2021.
//  Copyright © 2021 Dmitry Matyushkin. All rights reserved.
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
    @NSManaged public var recordid: String?
    @NSManaged public var good: Good?

}

extension GoodRating: Identifiable {

}
