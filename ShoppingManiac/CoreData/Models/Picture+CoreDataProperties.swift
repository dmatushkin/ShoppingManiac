//
//  Picture+CoreDataProperties.swift
//  ShoppingManiac
//
//  Created by Dmitry Matyushkin on 9/14/19.
//  Copyright © 2019 Dmitry Matyushkin. All rights reserved.
//
//

import Foundation
import CoreData


extension Picture {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<Picture> {
        return NSFetchRequest<Picture>(entityName: "Picture")
    }

    @NSManaged public var image: Data?
    @NSManaged public var shotDate: TimeInterval
    @NSManaged public var good: Good?

}
