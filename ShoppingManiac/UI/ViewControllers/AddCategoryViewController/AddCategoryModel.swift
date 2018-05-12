//
//  AddCategoryModel.swift
//  ShoppingManiac
//
//  Created by Dmitry Matyushkin on 12/05/2018.
//  Copyright © 2018 Dmitry Matyushkin. All rights reserved.
//

import Foundation
import RxSwift
import RxCocoa
import CoreStore


class AddCategoryModel {
    
    var category: Category?
    
    let disposeBag = DisposeBag()
    
    let categoryName = Variable<String>("")
    
    func applyData() {
        self.categoryName.value = self.category?.name ?? ""
    }
    
    private func createItem(withName name: String) {
        try? CoreStore.perform(synchronous: { transaction in
            let item = transaction.create(Into<Category>())
            item.name = name
        })
    }
    
    private func updateItem(item: Category, withName name: String) {
        try? CoreStore.perform(synchronous: { transaction in
            let item = transaction.edit(item)
            item?.name = name
        })
    }
    
    func persistData() {
        if let category = self.category {
            self.updateItem(item: category, withName: self.categoryName.value)
        } else {
            self.createItem(withName: self.categoryName.value)
        }
    }
}
