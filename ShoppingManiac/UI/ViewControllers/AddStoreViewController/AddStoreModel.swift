//
//  AddStoreModel.swift
//  ShoppingManiac
//
//  Created by Dmitry Matyushkin on 12/05/2018.
//  Copyright © 2018 Dmitry Matyushkin. All rights reserved.
//

import Foundation
import RxSwift
import RxCocoa
import CoreData

class AddStoreModel {
    
    var store: Store?
    
    let disposeBag = DisposeBag()
    
    let storeName = BehaviorRelay<String>(value: "")
    
    func applyData() {
        self.storeName.accept(self.store?.name ?? "") 
    }
    
    private func createItem(withName name: String) {
        DAO.performSync(updates: {context -> Void in
            let item: Store = context.create()
            item.name = name
        })
    }
    
    private func updateItem(item: Store, withName name: String) {
        DAO.performSync(updates: {context -> Void in
            let item = context.edit(item)
            item?.name = name
        })
    }
    
    func persistData() {
        if let store = store {
            self.updateItem(item: store, withName: self.storeName.value)
        } else {
            self.createItem(withName: self.storeName.value)
        }
    }
}
