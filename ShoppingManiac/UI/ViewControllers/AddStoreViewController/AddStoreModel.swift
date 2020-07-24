//
//  AddStoreModel.swift
//  ShoppingManiac
//
//  Created by Dmitry Matyushkin on 12/05/2018.
//  Copyright © 2018 Dmitry Matyushkin. All rights reserved.
//

import Foundation
import Combine
import CoreStore

class AddStoreModel {
    
    var store: Store?
    
    var cancellables = Set<AnyCancellable>()
    
    let storeName = CurrentValueSubject<String?, Never>("")
    
    func applyData() {
        self.storeName.send(self.store?.name ?? "")
    }
    
	func persistDataAsync() -> AnyPublisher<Void, Error> {
		if let store = self.store {
			return self.updateItemAssync(item: store, withName: self.storeName.value)
		} else {
			return self.createItemAsync(withName: self.storeName.value)
		}
	}

	func createItemAsync(withName name: String?) -> AnyPublisher<Void, Error> {
		return CoreDataOperationPublisher(operation: {transaction -> Void in
			let item = transaction.create(Into<Store>())
            item.name = name
		}).eraseToAnyPublisher()
	}

	func updateItemAssync(item: Store, withName name: String?) -> AnyPublisher<Void, Error> {
		return CoreDataOperationPublisher(operation: {transaction -> Void in
			let item = transaction.edit(item)
            item?.name = name
		}).eraseToAnyPublisher()
	}
}
