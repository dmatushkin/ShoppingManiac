//
//  Picture+CoreDataProperties.swift
//  ShoppingManiac
//
//  Created by Dmitry Matyushkin on 19.05.2021.
//  Copyright © 2021 Dmitry Matyushkin. All rights reserved.
//
//

import Foundation
import CoreData

extension Picture {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<Picture> {
        return NSFetchRequest<Picture>(entityName: "Picture")
    }

    @NSManaged public var image: Data?
    @NSManaged public var recordid: String?
    @NSManaged public var shotDate: TimeInterval
    @NSManaged public var good: Good?

}

extension Picture: Identifiable {

}
