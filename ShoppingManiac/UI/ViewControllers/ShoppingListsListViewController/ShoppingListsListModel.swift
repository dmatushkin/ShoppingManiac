//
//  ShoppingListsListModel.swift
//  ShoppingManiac
//
//  Created by Dmitry Matyushkin on 09/05/2018.
//  Copyright © 2018 Dmitry Matyushkin. All rights reserved.
//

import Foundation
import CoreStore
import Combine

class ShoppingListsListModel {
    
	private var cancellables = Set<AnyCancellable>()
    var onUpdate: (() -> Void)?
    private let cloudShare = CloudShare()
    
    init() {
        LocalNotifications.newDataAvailable.listen().sink(receiveCompletion: {_ in }, receiveValue: self.updateNeeded).store(in: &cancellables)
    }
    
    private func updateNeeded() {
        self.onUpdate?()
    }
    
    func itemsCount() -> Int {
        return (try? CoreStoreDefaults.dataStack.fetchCount(From<ShoppingList>().where(Where("isRemoved == false")))) ?? 0
    }
    
    func getItem(forIndex: IndexPath) -> ShoppingList? {
        return try? CoreStoreDefaults.dataStack.fetchOne(From<ShoppingList>().where(Where("isRemoved == false")).orderBy(.descending(\.date)).tweak({ fetchRequest in
            fetchRequest.fetchOffset = forIndex.row
            fetchRequest.fetchLimit = 1
        }))
    }
    
    func deleteItem(shoppingList: ShoppingList) {
        CoreStoreDefaults.dataStack.perform(asynchronous: { transaction in
            let list = transaction.edit(shoppingList)
            list?.isRemoved = true
        }, completion: {[weak self] _ in
            guard let self = self else { return }
            if AppDelegate.discoverabilityStatus && shoppingList.recordid != nil {
				self.cloudShare.updateList(list: shoppingList).sink(receiveCompletion: {_ in}, receiveValue: {}).store(in: &self.cancellables)
            }
            self.onUpdate?()
        })
    }
}
