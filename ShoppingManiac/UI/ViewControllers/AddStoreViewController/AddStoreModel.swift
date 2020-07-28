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
		return CoreDataOperationPublisher(operation: {[weak self] transaction -> Void in
			guard let self = self else { return }
			let item = self.store.flatMap({ transaction.edit($0) }) ?? transaction.create(Into<Store>())
			item.name = self.storeName.value
		}).eraseToAnyPublisher()
	}
}
