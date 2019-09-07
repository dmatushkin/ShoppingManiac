//
//  Store+CoreDataClass.swift
//  ShoppingManiac
//
//  Created by Dmitry Matyushkin on 21/05/2017.
//  Copyright © 2017 Dmitry Matyushkin. All rights reserved.
//

import Foundation
import CoreData

public class Store: NSManagedObject {
    
    class func item(forName name: String, inContext context: NSManagedObjectContext) -> Store {
        let store = context.fetchOne(Store.self, predicate: NSPredicate(format: "name == %@", name)) ?? context.create()
        store.name = name
        return store
    }
}
