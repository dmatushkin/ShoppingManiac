//
//  AddShoppingListModel.swift
//  ShoppingManiac
//
//  Created by Dmitry Matyushkin on 09/05/2018.
//  Copyright © 2018 Dmitry Matyushkin. All rights reserved.
//

import Foundation
import CoreStore
import RxSwift
import RxCocoa

class AddShoppingListModel {
    
    let listTitle = BehaviorRelay<String>(value: "")
    
    func createItem() -> ShoppingList? {
        do {
            let list: ShoppingList = try CoreStoreDefaults.dataStack.perform(synchronous: { transaction in
                let item = transaction.create(Into<ShoppingList>())
                item.name = self.listTitle.value
                item.date = Date().timeIntervalSinceReferenceDate
                return item
            })
            return CoreStoreDefaults.dataStack.fetchExisting(list)
        } catch {
            return nil
        }
    }
}
