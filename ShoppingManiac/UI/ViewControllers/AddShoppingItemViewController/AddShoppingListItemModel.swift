//
//  AddShoppingListItemModel.swift
//  ShoppingManiac
//
//  Created by Dmitry Matyushkin on 11/05/2018.
//  Copyright © 2018 Dmitry Matyushkin. All rights reserved.
//

import Foundation
import Combine
import CoreStore

class AddShoppingListItemModel {
    
    var shoppingListItem: ShoppingListItem?
    var shoppingList: ShoppingList!
    
    var cancellables = Set<AnyCancellable>()
    
    let itemName = CurrentValueSubject<String?, Never>("")
    let storeName = CurrentValueSubject<String?, Never>("")
    let priceText = CurrentValueSubject<String?, Never>("")
    let amountText = CurrentValueSubject<String?, Never>("")
    let isWeight = CurrentValueSubject<Bool, Never>(false)
    let rating = CurrentValueSubject<Int, Never>(0)
    let crossListItem = CurrentValueSubject<Bool, Never>(false)
    
    func listAllGoods() -> [String] {
        return (try? CoreStoreDefaults.dataStack.fetchAll(From<Good>().orderBy(.ascending(\.name))))?.map({ $0.name }).filter({ $0 != nil && $0!.count > 0 }).map({ $0! }) ?? []
    }
    
    func listAllStores() -> [String] {
        return (try? CoreStoreDefaults.dataStack.fetchAll(From<Store>().orderBy(.ascending(\.name))))?.map({ $0.name }).filter({ $0 != nil && $0!.count > 0 }).map({ $0! }) ?? []
    }
    
    func applyData() {
        self.itemName.send(self.shoppingListItem?.good?.name ?? "")
        self.storeName.send(self.shoppingListItem?.store?.name ?? "")
        if let price = self.shoppingListItem?.price, price > 0 {
            self.priceText.send("\(price)")
        }
        if let amount = self.shoppingListItem?.quantityText {
            self.amountText.send(amount)
        }
        self.isWeight.send((self.shoppingListItem?.isWeight == true))
        self.rating.send(Int(self.shoppingListItem?.good?.personalRating ?? 0))
        self.crossListItem.send(self.shoppingListItem?.isCrossListItem ?? false)
    }
    
	func persistDataAsync() -> AnyPublisher<Void, Error> {
		return CoreDataOperationPublisher(operation: {transaction -> Void in
			let item = self.shoppingListItem.flatMap({ transaction.edit($0) }) ?? transaction.create(Into<ShoppingListItem>())
			item.list = transaction.edit(self.shoppingList)
			item.good = try Good.item(forName: self.itemName.value ?? "", inTransaction: transaction)
			item.isWeight = self.isWeight.value
			item.good?.personalRating = Int16(self.rating.value)
			if self.storeName.value?.isEmpty ?? true {
				item.store = nil
			} else {
				item.store = try Store.item(forName: self.storeName.value ?? "", inTransaction: transaction)
			}
			let amount = self.amountText.value?.replacingOccurrences(of: ",", with: ".") ?? ""
			if amount.count > 0, let value = Float(amount) {
				item.quantity = value
			} else {
				item.quantity = 1
			}
			let price = self.priceText.value?.replacingOccurrences(of: ",", with: ".") ?? ""
			if price.count > 0, let value = Float(price) {
				item.price = value
			} else {
				item.price = 0
			}
			item.isCrossListItem = self.crossListItem.value
			item.isRemoved = false
			if self.shoppingListItem == nil {
				item.purchased = false
			}
		}).eraseToAnyPublisher()
	}
}
