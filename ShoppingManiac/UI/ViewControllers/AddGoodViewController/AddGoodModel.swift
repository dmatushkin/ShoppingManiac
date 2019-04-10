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
import NoticeObserveKit
import CoreStore

class AddGoodModel {
    
    var good: Good?
    var category: Category? = nil {
        didSet {
            self.goodCategory.value = category?.name ?? ""
        }
    }
    
    let disposeBag = DisposeBag()
    
    let goodName = Variable<String>("")
    let goodCategory = Variable<String>("")
    let rating = Variable<Int>(0)
    
    func applyData() {
        self.goodName.value = self.good?.name ?? ""
        self.goodCategory.value = self.good?.category?.name ?? ""
        self.category = good?.category
        self.rating.value = Int(good?.personalRating ?? 0)
    }
    
    func persistChanges() {
        if let good = self.good {
            self.updateItem(item: good, withName: self.goodName.value)
        } else {
            self.createItem(withName: self.goodName.value)
        }
    }
    
    private func createItem(withName name: String) {
        try? CoreStore.perform(synchronous: { transaction in
            let item = transaction.create(Into<Good>())
            item.name = name
            item.category = transaction.edit(self.category)
            item.personalRating = Int16(self.rating.value)
        })
    }
    
    private func updateItem(item: Good, withName name: String) {
        try? CoreStore.perform(synchronous: { transaction in
            let item = transaction.edit(item)
            item?.name = name
            item?.category = transaction.edit(self.category)
            item?.personalRating = Int16(self.rating.value)
        })
    }
    
    func categoriesCount() -> Int {
        return (try? CoreStore.fetchCount(From<Category>(), [])) ?? 0
    }
    
    func getCategoryItem(forIndex: IndexPath) -> Category? {
        return try? CoreStore.fetchOne(From<Category>().orderBy(.ascending(\.name)).tweak({ fetchRequest in
            fetchRequest.fetchOffset = forIndex.row
            fetchRequest.fetchLimit = 1
        }))
    }
}
