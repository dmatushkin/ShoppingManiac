//
//  Picture+CoreDataProperties.swift
//  ShoppingManiac
//
//  Created by Dmitry Matyushkin on 21/05/2017.
//  Copyright © 2017 Dmitry Matyushkin. All rights reserved.
//

import Foundation
import CoreData

extension Picture {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<Picture> {
        return NSFetchRequest<Picture>(entityName: "Picture")
    }

    @NSManaged public var image: NSData?
    @NSManaged public var recordid: String?
    @NSManaged public var shotDate: TimeInterval
    @NSManaged public var good: Good?

}
