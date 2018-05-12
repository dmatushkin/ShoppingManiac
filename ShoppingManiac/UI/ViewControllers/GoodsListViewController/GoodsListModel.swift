//
//  GoodsListModel.swift
//  ShoppingManiac
//
//  Created by Dmitry Matyushkin on 12/05/2018.
//  Copyright © 2018 Dmitry Matyushkin. All rights reserved.
//

import Foundation
import RxSwift
import RxCocoa
import NoticeObserveKit
import CoreStore

class GoodsListModel {
    
    let disposeBag = DisposeBag()
    private let pool = NoticeObserverPool()
    var onUpdate: (() -> Void)?
    
    init() {
        NewDataAvailable.observe {[weak self] _ in
            self?.onUpdate?()
            }.disposed(by: self.pool)
    }
    
    func itemsCount() -> Int {
        return CoreStore.fetchCount(From<Good>(), []) ?? 0
    }
    
    func getItem(forIndex: IndexPath) -> Good? {
        return CoreStore.fetchOne(From<Good>().orderBy(.ascending(\.name)).tweak({ fetchRequest in
            fetchRequest.fetchOffset = forIndex.row
            fetchRequest.fetchLimit = 1
        }))
    }
    
    func deleteItem(good: Good) {
        CoreStore.perform(asynchronous: { transaction in
            transaction.delete(good)
        }, completion: {[weak self] _ in
            self?.onUpdate?()
        })
    }
}
