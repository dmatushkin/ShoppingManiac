//
//  CategoriesListModel.swift
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

class CategoriesListModel {
    
    let disposeBag = DisposeBag()
    private let pool = NoticeObserverPool()
    var onUpdate: (() -> Void)?
    
    init() {
        NewDataAvailable.observe {[weak self] _ in
            self?.onUpdate?()
        }.disposed(by: self.pool)
    }
    
    func itemsCount() -> Int {
        return CoreStore.fetchCount(From<Category>(), []) ?? 0
    }
    
    func getItem(forIndex: IndexPath) -> Category? {
        return CoreStore.fetchOne(From<Category>().orderBy(.ascending(\.name)).tweak({ fetchRequest in
            fetchRequest.fetchOffset = forIndex.row
            fetchRequest.fetchLimit = 1
        }))
    }
    
    func deleteItem(item: Category) {
        CoreStore.perform(asynchronous: { transaction in
            transaction.delete(item)
        }, completion: {[weak self] _ in
            self?.onUpdate?()
        })
    }
}
