//
//  GoodsListModel.swift
//  ShoppingManiac
//
//  Created by Dmitry Matyushkin on 12/05/2018.
//  Copyright © 2018 Dmitry Matyushkin. All rights reserved.
//

import Foundation
import CoreStore
import Combine

class GoodsListModel {
    
	private var cancellables = Set<AnyCancellable>()
    var onUpdate: (() -> Void)?
    
    init() {
		LocalNotifications.newDataAvailable.listen().sink(receiveCompletion: {_ in }, receiveValue: self.updateNeeded).store(in: &cancellables)
    }
    
    private func updateNeeded() {
        self.onUpdate?()
    }
    
    func itemsCount() -> Int {
        return (try? CoreStoreDefaults.dataStack.fetchCount(From<Good>(), [])) ?? 0
    }
    
    func getItem(forIndex: IndexPath) -> Good? {
        return try? CoreStoreDefaults.dataStack.fetchOne(From<Good>().orderBy(.ascending(\.name)).tweak({ fetchRequest in
            fetchRequest.fetchOffset = forIndex.row
            fetchRequest.fetchLimit = 1
        }))
    }
    
    func deleteItem(good: Good) {
        CoreStoreDefaults.dataStack.perform(asynchronous: { transaction in
            transaction.delete(good)
        }, completion: {[weak self] _ in
            self?.onUpdate?()
        })
    }
}
