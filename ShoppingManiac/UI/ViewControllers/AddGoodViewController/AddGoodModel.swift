//
//  AddGoodModel.swift
//  ShoppingManiac
//
//  Created by Dmitry Matyushkin on 12/05/2018.
//  Copyright © 2018 Dmitry Matyushkin. All rights reserved.
//

import Foundation
import CoreStore
import CoreData
import Combine

class AddGoodModel {

    var good: Good?
    var category: Category? = nil {
        didSet {
            self.goodCategory.send(category?.name ?? "")
        }
    }
    
    let goodName = CurrentValueSubject<String?, Never>("")
    let goodCategory = CurrentValueSubject<String?, Never>("")
    let rating = CurrentValueSubject<Int, Never>(0)
    
    func applyData() {
        self.goodName.send(self.good?.name ?? "")
        self.goodCategory.send(self.good?.category?.name ?? "")
        self.category = good?.category
        self.rating.send(Int(good?.personalRating ?? 0))
    }
    
	func persistChangesAsync() -> AnyPublisher<Void, Error> {
		if let good = self.good {
			return self.updateItemAsync(item: good, withName: self.goodName.value)
		} else {
			return self.createItemAsync(withName: self.goodName.value)
		}
	}

	private func createItemAsync(withName name: String?) -> AnyPublisher<Void, Error> {
		return CoreDataOperationPublisher(operation: {[weak self] transaction -> Void in
			guard let self = self else { return }
			let item = transaction.create(Into<Good>())
            item.name = name
            item.category = transaction.edit(self.category)
            item.personalRating = Int16(self.rating.value)
			}).eraseToAnyPublisher()
	}

	private func updateItemAsync(item: Good, withName name: String?) -> AnyPublisher<Void, Error> {
		return CoreDataOperationPublisher(operation: {[weak self] transaction -> Void in
			guard let self = self else { return }
			let item = transaction.edit(item)
            item?.name = name
            item?.category = transaction.edit(self.category)
            item?.personalRating = Int16(self.rating.value)
		}).eraseToAnyPublisher()
	}

    func categoriesCount() -> Int {
        return (try? CoreStoreDefaults.dataStack.fetchCount(From<Category>(), [])) ?? 0
    }
    
    func getCategoryItem(forIndex: IndexPath) -> Category? {
        return try? CoreStoreDefaults.dataStack.fetchOne(From<Category>().orderBy(.ascending(\.name)).tweak({ fetchRequest in
            fetchRequest.fetchOffset = forIndex.row
            fetchRequest.fetchLimit = 1
        }))
    }
}
