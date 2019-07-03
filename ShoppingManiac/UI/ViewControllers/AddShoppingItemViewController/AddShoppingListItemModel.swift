//
//  AddShoppingListItemModel.swift
//  ShoppingManiac
//
//  Created by Dmitry Matyushkin on 11/05/2018.
//  Copyright © 2018 Dmitry Matyushkin. All rights reserved.
//

import Foundation
import RxSwift
import RxCocoa
import CoreStore

class AddShoppingListItemModel {
    
    var shoppingListItem: ShoppingListItem?
    var shoppingList: ShoppingList!
    
    let disposeBag = DisposeBag()
    
    let itemName = BehaviorRelay<String>(value: "")
    let storeName = BehaviorRelay<String>(value: "")
    let priceText = BehaviorRelay<String>(value: "")
    let amountText = BehaviorRelay<String>(value: "")
    let isWeight = BehaviorRelay<Bool>(value: false)
    let rating = BehaviorRelay<Int>(value: 0)
    let crossListItem = BehaviorRelay<Bool>(value: false)
    
    func listAllGoods() -> [String] {
        return (try? CoreStore.fetchAll(From<Good>().orderBy(.ascending(\.name))))?.map({ $0.name }).filter({ $0 != nil && $0!.count > 0 }).map({ $0! }) ?? []
    }
    
    func listAllStores() -> [String] {
        return (try? CoreStore.fetchAll(From<Store>().orderBy(.ascending(\.name))))?.map({ $0.name }).filter({ $0 != nil && $0!.count > 0 }).map({ $0! }) ?? []
    }
    
    func applyData() {
        self.itemName.accept(self.shoppingListItem?.good?.name ?? "")
        self.storeName.accept(self.shoppingListItem?.store?.name ?? "")
        if let price = self.shoppingListItem?.price, price > 0 {
            self.priceText.accept("\(price)")
        }
        if let amount = self.shoppingListItem?.quantityText {
            self.amountText.accept(amount)
        }
        self.isWeight.accept((self.shoppingListItem?.isWeight == true))
        self.rating.accept(Int(self.shoppingListItem?.good?.personalRating ?? 0))
        self.crossListItem.accept(self.shoppingListItem?.isCrossListItem ?? false)
    }
    
    func persistData() {
        try? CoreStore.perform(synchronous: { transaction in
            let item = self.shoppingListItem == nil ? transaction.create(Into<ShoppingListItem>()) : transaction.edit(self.shoppingListItem)
            item?.good = try Good.item(forName: self.itemName.value, inTransaction: transaction)
            item?.isWeight = self.isWeight.value
            item?.good?.personalRating = Int16(self.rating.value)
            if self.storeName.value.count > 0 {
                item?.store = try Store.item(forName: self.storeName.value, inTransaction: transaction)
            } else {
                item?.store = nil
            }
            let amount = self.amountText.value.replacingOccurrences(of: ",", with: ".")
            if amount.count > 0, let value = Float(amount) {
                item?.quantity = value
            } else {
                item?.quantity = 1
            }
            let price = self.priceText.value.replacingOccurrences(of: ",", with: ".")
            if price.count > 0, let value = Float(price) {
                item?.price = value
            } else {
                item?.price = 0
            }
            item?.isCrossListItem = self.crossListItem.value
            item?.list = transaction.edit(self.shoppingList)
        })
    }
}
