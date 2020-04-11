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
    
    let categoryName = BehaviorRelay<String>(value: "")
    
    func applyData() {
        self.categoryName.accept(self.category?.name ?? "")
    }
    
	func persistDataAsync() -> Observable<Void> {
		if let category = self.category {
			return self.updateItemAssync(item: category, withName: self.categoryName.value)
		} else {
			return self.createItemAsync(withName: self.categoryName.value)
		}
	}

	func createItemAsync(withName name: String) -> Observable<Void> {
		return Observable<Void>.performCoreStore({transaction -> Void in
			let item = transaction.create(Into<Category>())
            item.name = name
		})
	}

	func updateItemAssync(item: Category, withName name: String) -> Observable<Void> {
		return Observable<Void>.performCoreStore({transaction -> Void in
			let item = transaction.edit(item)
            item?.name = name
		})
	}
}
