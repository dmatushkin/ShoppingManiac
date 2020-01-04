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
import CoreStore

class AddStoreModel {
    
    var store: Store?
    
    let disposeBag = DisposeBag()
    
    let storeName = BehaviorRelay<String>(value: "")
    
    func applyData() {
        self.storeName.accept(self.store?.name ?? "") 
    }
    
    private func createItem(withName name: String) {
        try? CoreStoreDefaults.dataStack.perform(synchronous: { transaction in
            let item = transaction.create(Into<Store>())
            item.name = name
        })
    }
    
    private func updateItem(item: Store, withName name: String) {
        try? CoreStoreDefaults.dataStack.perform(synchronous: { transaction in
            let item = transaction.edit(item)
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
