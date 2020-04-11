//
//  AddGoodModel.swift
//  ShoppingManiac
//
//  Created by Dmitry Matyushkin on 12/05/2018.
//  Copyright © 2018 Dmitry Matyushkin. All rights reserved.
//

import Foundation
import RxSwift
import RxCocoa
import CoreStore
import CoreData

class AddGoodModel {
    
    var good: Good?
    var category: Category? = nil {
        didSet {
            self.goodCategory.accept(category?.name ?? "")
        }
    }
    
    let disposeBag = DisposeBag()
    
    let goodName = BehaviorRelay<String>(value: "")
    let goodCategory = BehaviorRelay<String>(value: "")
    let rating = BehaviorRelay<Int>(value: 0)
    
    func applyData() {
        self.goodName.accept(self.good?.name ?? "")
        self.goodCategory.accept(self.good?.category?.name ?? "")
        self.category = good?.category
        self.rating.accept(Int(good?.personalRating ?? 0))
    }
    
	func persistChangesAsync() -> Observable<Void> {
		if let good = self.good {
			return self.updateItemAsync(item: good, withName: self.goodName.value)
		} else {
			return self.createItemAsync(withName: self.goodName.value)
		}
	}

	private func createItemAsync(withName name: String) -> Observable<Void> {
		Observable<Void>.performCoreStore {transaction -> Void in
			let item = transaction.create(Into<Good>())
            item.name = name
            item.category = transaction.edit(self.category)
            item.personalRating = Int16(self.rating.value)
		}
	}

	private func updateItemAsync(item: Good, withName name: String) -> Observable<Void> {
		Observable<Void>.performCoreStore({transaction -> Void in
			let item = transaction.edit(item)
            item?.name = name
            item?.category = transaction.edit(self.category)
            item?.personalRating = Int16(self.rating.value)
		})
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
