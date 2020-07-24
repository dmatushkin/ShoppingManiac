//
//  AddCategoryModel.swift
//  ShoppingManiac
//
//  Created by Dmitry Matyushkin on 12/05/2018.
//  Copyright © 2018 Dmitry Matyushkin. All rights reserved.
//

import Foundation
import CoreStore
import Combine

class AddCategoryModel {
    
    var category: Category?
    
    var cancellables = Set<AnyCancellable>()
    
    let categoryName = CurrentValueSubject<String?, Never>("")
    
    func applyData() {
        self.categoryName.send(self.category?.name ?? "")
    }
    
	func persistDataAsync() -> AnyPublisher<Void, Error> {
		if let category = self.category {
			return self.updateItemAssync(item: category, withName: self.categoryName.value)
		} else {
			return self.createItemAsync(withName: self.categoryName.value)
		}
	}

	func createItemAsync(withName name: String?) -> AnyPublisher<Void, Error> {
		return CoreDataOperationPublisher(operation: {transaction -> Void in
			let item = transaction.create(Into<Category>())
            item.name = name
		}).eraseToAnyPublisher()
	}

	func updateItemAssync(item: Category, withName name: String?) -> AnyPublisher<Void, Error> {
		return CoreDataOperationPublisher(operation: {transaction -> Void in
			let item = transaction.edit(item)
            item?.name = name
		}).eraseToAnyPublisher()
	}
}
