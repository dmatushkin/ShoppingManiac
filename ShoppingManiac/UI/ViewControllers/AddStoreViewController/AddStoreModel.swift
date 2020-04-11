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
    
	func persistDataAsync() -> Observable<Void> {
		if let store = self.store {
			return self.updateItemAssync(item: store, withName: self.storeName.value)
		} else {
			return self.createItemAsync(withName: self.storeName.value)
		}
	}

	func createItemAsync(withName name: String) -> Observable<Void> {
		return Observable<Void>.performCoreStore({transaction -> Void in
			let item = transaction.create(Into<Store>())
            item.name = name
		})
	}

	func updateItemAssync(item: Store, withName name: String) -> Observable<Void> {
		return Observable<Void>.performCoreStore({transaction -> Void in
			let item = transaction.edit(item)
            item?.name = name
		})
	}
}
