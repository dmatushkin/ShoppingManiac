//
//  StoresListModel.swift
//  ShoppingManiac
//
//  Created by Dmitry Matyushkin on 12/05/2018.
//  Copyright © 2018 Dmitry Matyushkin. All rights reserved.
//

import Foundation
import CoreStore
import RxSwift
import RxCocoa
import NoticeObserveKit

class StoresListModel {
    
    let disposeBag = DisposeBag()
    private let pool = NoticeObserverPool()
    var onUpdate: (() -> Void)?
    
    init() {
        NewDataAvailable.observe {[weak self] _ in
            self?.onUpdate?()
        }.disposed(by: self.pool)
    }
    
    func itemsCount() -> Int {
        return CoreStore.fetchCount(From<Store>(), []) ?? 0
    }
    
    func getItem(forIndex: IndexPath) -> Store? {
        return CoreStore.fetchOne(From<Store>().orderBy(.ascending(\.name)).tweak({ fetchRequest in
            fetchRequest.fetchOffset = forIndex.row
            fetchRequest.fetchLimit = 1
        }))
    }
    
    func deleteItem(item: Store) {
        CoreStore.perform(asynchronous: { transaction in
            transaction.delete(item)
        }, completion: {[weak self] _ in
            self?.onUpdate?()
        })
    }
}
