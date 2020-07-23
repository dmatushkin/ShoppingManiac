//
//  StoresListModel.swift
//  ShoppingManiac
//
//  Created by Dmitry Matyushkin on 12/05/2018.
//  Copyright © 2018 Dmitry Matyushkin. All rights reserved.
//

import Foundation
import CoreStore
import Combine

class StoresListModel {
    
    private var cancellables = Set<AnyCancellable>()
    var onUpdate: (() -> Void)?
    
    init() {
        LocalNotifications.newDataAvailable.listen().sink(receiveCompletion: {_ in }, receiveValue: self.updateNeeded).store(in: &cancellables)
    }
    
    private func updateNeeded() {
        self.onUpdate?()
    }
        
    func itemsCount() -> Int {
        return (try? CoreStoreDefaults.dataStack.fetchCount(From<Store>(), [])) ?? 0
    }
    
    func getItem(forIndex: IndexPath) -> Store? {
        return try? CoreStoreDefaults.dataStack.fetchOne(From<Store>().orderBy(.ascending(\.name)).tweak({ fetchRequest in
            fetchRequest.fetchOffset = forIndex.row
            fetchRequest.fetchLimit = 1
        }))
    }
    
    func deleteItem(item: Store) {
        CoreStoreDefaults.dataStack.perform(asynchronous: { transaction in
            transaction.delete(item)
        }, completion: {[weak self] _ in
            self?.onUpdate?()
        })
    }
}
