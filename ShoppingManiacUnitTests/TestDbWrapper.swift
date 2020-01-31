//
//  TestDbWrapper.swift
//  ShoppingManiacUnitTests
//
//  Created by Dmitry Matyushkin on 2/1/20.
//  Copyright © 2020 Dmitry Matyushkin. All rights reserved.
//

import CoreStore
import XCTest

class TestDbWrapper {
    
    private static let stack: DataStack = {
        let stack = DataStack(xcodeModelName: "ShoppingManiac", bundle: Bundle(for: CloudShareUnitTests.self))
        do {
            try stack.addStorageAndWait(InMemoryStore())
        } catch {
            XCTFail("Cannot set up database storage: \(error)")
        }        
        return stack
    }()
    
    class func setup() {
        CoreStoreDefaults.dataStack = stack
    }
    
    class func cleanup() {
        do {
            _ = try CoreStoreDefaults.dataStack.perform(synchronous: { transaction in
                try transaction.deleteAll(From<ShoppingList>())
                try transaction.deleteAll(From<Store>())
                try transaction.deleteAll(From<Good>())
                try transaction.deleteAll(From<Category>())
                try transaction.deleteAll(From<ShoppingListItem>())
            })
        } catch {
            print(error.localizedDescription)
        }
    }
}
