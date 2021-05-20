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
import UIKit

class AddGoodModel {

    var good: Good?
    
    let goodName = CurrentValueSubject<String?, Never>("")
    let goodCategory = CurrentValueSubject<String?, Never>("")
    let rating = CurrentValueSubject<Int, Never>(0)

    func listAllCategories() -> [String] {
        return (try? CoreStoreDefaults.dataStack.fetchAll(From<Category>().orderBy(.ascending(\.name))))?.compactMap({ $0.name?.nilIfEmpty }) ?? []
    }
    
    func applyData() {
        self.goodName.send(self.good?.name ?? "")
        self.goodCategory.send(self.good?.category?.name ?? "")
        self.rating.send(Int(good?.personalRating ?? 0))
    }
    
	func persistChangesAsync() -> AnyPublisher<Void, Error> {
		return CoreDataOperationPublisher(operation: {[weak self] transaction -> Void in
			guard let self = self else { return }
			let item = self.good.flatMap({ transaction.edit($0) }) ?? transaction.create(Into<Good>())
			item.name = self.goodName.value
            if let categoryName = self.goodCategory.value?.nilIfEmpty {
                do {
                    let category = try transaction.fetchOne(From<Category>().where(Where("name == %@", categoryName))) ?? transaction.create(Into<Category>())
                    category.name = categoryName
                    item.category = category
                } catch {
                    item.category = nil
                }                
            } else {
                item.category = nil
            }
            item.personalRating = Int16(self.rating.value)
		}).eraseToAnyPublisher()
	}
}
