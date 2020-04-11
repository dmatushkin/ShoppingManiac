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
    
	func createItemAsync() -> Observable<ShoppingList> {
		return Observable<ShoppingList>.performCoreStore({transaction -> ShoppingList in
			let item = transaction.create(Into<ShoppingList>())
			item.name = self.listTitle.value
			item.date = Date().timeIntervalSinceReferenceDate
			return item
		})
	}
}
