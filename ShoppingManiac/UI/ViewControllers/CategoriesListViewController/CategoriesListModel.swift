//
//  CategoriesListModel.swift
//  ShoppingManiac
//
//  Created by Dmitry Matyushkin on 12/05/2018.
//  Copyright © 2018 Dmitry Matyushkin. All rights reserved.
//

import Foundation
import CoreStore
import Combine

class CategoriesListModel {
    
    private var cancellables = Set<AnyCancellable>()
    var onUpdate: (() -> Void)?
    
    init() {
        LocalNotifications.newDataAvailable.listen().sink(receiveCompletion: {_ in }, receiveValue: self.updateNeeded).store(in: &cancellables)
    }
    
    private func updateNeeded() {
        self.onUpdate?()
    }
    
    func itemsCount() -> Int {
        return (try? CoreStoreDefaults.dataStack.fetchCount(From<Category>(), [])) ?? 0
    }
    
    func getItem(forIndex: IndexPath) -> Category? {
        return try? CoreStoreDefaults.dataStack.fetchOne(From<Category>().orderBy(.ascending(\.name)).tweak({ fetchRequest in
            fetchRequest.fetchOffset = forIndex.row
            fetchRequest.fetchLimit = 1
        }))
    }
    
    func deleteItem(item: Category) {
        CoreStoreDefaults.dataStack.perform(asynchronous: { transaction in
            transaction.delete(item)
        }, completion: {[weak self] _ in
            self?.onUpdate?()
        })
    }
}
