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
    
    func persistChanges() {
        if let good = self.good {
            self.updateItem(item: good, withName: self.goodName.value)
        } else {
            self.createItem(withName: self.goodName.value)
        }
    }
    
    private func createItem(withName name: String) {
        DAO.performSync(updates: {[weak self] context -> Void in
            guard let self = self else { return }
            let item: Good = context.create()
            item.name = name
            item.category = context.edit(self.category)
            item.personalRating = Int16(self.rating.value)
        })
    }
    
    private func updateItem(item: Good, withName name: String) {
        DAO.performSync(updates: {[weak self] context -> Void in
            guard let self = self else { return }
            let item = context.edit(item)
            item?.name = name
            item?.category = context.edit(self.category)
            item?.personalRating = Int16(self.rating.value)
        })
    }
    
    func categoriesCount() -> Int {
        return DAO.fetchCount(Category.self)
    }
    
    func getCategoryItem(forIndex: IndexPath) -> Category? {
        return DAO.fetchOne(Category.self, sort: [NSSortDescriptor(key: "name", ascending: true)], index: forIndex.row)
    }
}
