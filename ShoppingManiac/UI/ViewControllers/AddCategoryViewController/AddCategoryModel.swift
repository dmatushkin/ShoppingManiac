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
import CoreData

class AddCategoryModel {
    
    var category: Category?
    
    let disposeBag = DisposeBag()
    
    let categoryName = BehaviorRelay<String>(value: "")
    
    func applyData() {
        self.categoryName.accept(self.category?.name ?? "")
    }
    
    private func createItem(withName name: String) {
        DAO.performSync(updates: {context -> Void in
            let item: Category = context.create()
            item.name = name
        })
    }
    
    private func updateItem(item: Category, withName name: String) {
        DAO.performSync(updates: {context -> Void in
            let item = context.edit(item)
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
