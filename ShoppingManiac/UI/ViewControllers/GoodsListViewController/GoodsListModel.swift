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
import CoreStore

class GoodsListModel {
    
    let disposeBag = DisposeBag()
    var onUpdate: (() -> Void)?
    
    init() {
        LocalNotifications.newDataAvailable.listen().subscribe(onNext: self.updateNeeded).disposed(by: self.disposeBag)
    }
    
    private func updateNeeded() {
        self.onUpdate?()
    }
    
    func itemsCount() -> Int {
        return (try? CoreStore.fetchCount(From<Good>(), [])) ?? 0
    }
    
    func getItem(forIndex: IndexPath) -> Good? {
        return try? CoreStore.fetchOne(From<Good>().orderBy(.ascending(\.name)).tweak({ fetchRequest in
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
