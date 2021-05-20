//
//  Store+CoreDataClass.swift
//  ShoppingManiac
//
//  Created by Dmitry Matyushkin on 21/05/2017.
//  Copyright © 2017 Dmitry Matyushkin. All rights reserved.
//

import Foundation
import CoreData
import CoreStore

public class Store: NSManagedObject {
    
    class func item(forName name: String, inTransaction transaction: AsynchronousDataTransaction) throws -> Store {
        let store = try transaction.fetchOne(From<Store>().where(Where("name == %@", name))) ?? transaction.create(Into<Store>())
        store.name = name
        return store
    }
    
    var listCategories: [Category] {
        return (Array(self.orders ?? []) as? [CategoryStoreOrder] ?? []).sorted(by: { $0.order < $1.order }).compactMap({ $0.category })
    }
}
