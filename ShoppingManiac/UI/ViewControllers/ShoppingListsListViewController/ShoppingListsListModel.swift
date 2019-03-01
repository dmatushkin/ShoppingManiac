//
//  ShoppingListsListModel.swift
//  ShoppingManiac
//
//  Created by Dmitry Matyushkin on 09/05/2018.
//  Copyright © 2018 Dmitry Matyushkin. All rights reserved.
//

import Foundation
import CoreStore
import RxSwift
import NoticeObserveKit

class ShoppingListsListModel {
    
    let disposeBag = DisposeBag()
    private let pool = NoticeObserverPool()
    var onUpdate: (() -> Void)?
    
    init() {
        NewDataAvailable.observe {[weak self] _ in
            self?.onUpdate?()
        }.disposed(by: self.pool)
    }
    
    func itemsCount() -> Int {
        return CoreStore.fetchCount(From<ShoppingList>().where(Where("isRemoved == false"))) ?? 0
    }
    
    func getItem(forIndex: IndexPath) -> ShoppingList? {
        return CoreStore.fetchOne(From<ShoppingList>().where(Where("isRemoved == false")).orderBy(.descending(\.date)).tweak({ fetchRequest in
            fetchRequest.fetchOffset = forIndex.row
            fetchRequest.fetchLimit = 1
        }))
    }
    
    func deleteItem(shoppingList: ShoppingList) {
        CoreStore.perform(asynchronous: { transaction in
            let list = transaction.edit(shoppingList)
            list?.isRemoved = true
        }, completion: {[weak self] _ in
            guard let `self` = self else { return }
            if AppDelegate.discoverabilityStatus && shoppingList.recordid != nil {
                CloudShare.updateList(list: shoppingList).subscribe().disposed(by: self.disposeBag)
            }
            self.onUpdate?()
        })
    }
}
