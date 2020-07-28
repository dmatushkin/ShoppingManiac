//
//  AddCategoryModel.swift
//  ShoppingManiac
//
//  Created by Dmitry Matyushkin on 12/05/2018.
//  Copyright © 2018 Dmitry Matyushkin. All rights reserved.
//

import Foundation
import CoreStore
import Combine

class AddCategoryModel {
    
    var category: Category?
    
    var cancellables = Set<AnyCancellable>()
    
    let categoryName = CurrentValueSubject<String?, Never>("")
    
    func applyData() {
        self.categoryName.send(self.category?.name ?? "")
    }
    
	func persistDataAsync() -> AnyPublisher<Void, Error> {
		return CoreDataOperationPublisher(operation: {[weak self] transaction -> Void in
			guard let self = self else { return }
			let item = self.category.flatMap({ transaction.edit($0) }) ?? transaction.create(Into<Category>())
			item.name = self.categoryName.value
		}).eraseToAnyPublisher()
	}
}
