//
//  Good+CoreDataClass.swift
//  ShoppingManiac
//
//  Created by Dmitry Matyushkin on 21/05/2017.
//  Copyright © 2017 Dmitry Matyushkin. All rights reserved.
//

import Foundation
import CoreData
import CoreStore

public class Good: NSManagedObject {
    
    class func item(forName name: String, inTransaction transaction: SynchronousDataTransaction) throws -> Good {
        let good = try transaction.fetchOne(From<Good>().where(Where("name == %@", name))) ?? transaction.create(Into<Good>())
        good.name = name
        return good
    }
}
