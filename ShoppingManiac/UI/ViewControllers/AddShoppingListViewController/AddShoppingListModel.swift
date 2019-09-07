//
//  AddShoppingListModel.swift
//  ShoppingManiac
//
//  Created by Dmitry Matyushkin on 09/05/2018.
//  Copyright © 2018 Dmitry Matyushkin. All rights reserved.
//

import Foundation
import RxSwift
import RxCocoa

class AddShoppingListModel {
    
    let listTitle = BehaviorRelay<String>(value: "")
    
    func createItem() -> ShoppingList? {
        let list = DAO.performSync(updates: {context -> ShoppingList in
            let item: ShoppingList = context.create()
            item.name = self.listTitle.value
            item.date = Date().timeIntervalSinceReferenceDate
            return item
        })
        return DAO.fetchExisting(list)
    }
}
