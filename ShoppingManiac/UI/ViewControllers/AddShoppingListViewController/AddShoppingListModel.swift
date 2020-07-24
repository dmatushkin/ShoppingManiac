//
//  AddShoppingListModel.swift
//  ShoppingManiac
//
//  Created by Dmitry Matyushkin on 09/05/2018.
//  Copyright © 2018 Dmitry Matyushkin. All rights reserved.
//

import Foundation
import CoreStore
import Combine

class AddShoppingListModel {
    
	let listTitle = CurrentValueSubject<String?, Never>("")
    
	func createItemAsync() -> AnyPublisher<ShoppingList, Error> {
		return CoreDataOperationPublisher(operation: {[weak self] transaction -> ShoppingList in
			guard let self = self else { fatalError() }
			let item = transaction.create(Into<ShoppingList>())
			item.name = self.listTitle.value
			item.date = Date().timeIntervalSinceReferenceDate
			return item
		}).eraseToAnyPublisher()
	}
}
