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

class ShoppingListsListModel {
    
    let disposeBag = DisposeBag()
    var onUpdate: (() -> Void)?
    private let cloudShare = CloudShare(cloudKitUtils: CloudKitUtils(operations: CloudKitOperations(), storage: CloudKitTokenStorage()))
    
    init() {
        LocalNotifications.newDataAvailable.listen().subscribe(onNext: self.updateNeeded).disposed(by: self.disposeBag)
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
                self.cloudShare.updateList(list: shoppingList).subscribe().disposed(by: self.disposeBag)
            }
            self.onUpdate?()
        })
    }
}
