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
import CoreData

class GoodsListModel {
    
    let disposeBag = DisposeBag()
    var onUpdate: (() -> Void)?
    
    init() {
        LocalNotifications.newDataAvailable.listen().subscribe(onNext: self.onUpdate ?? {}).disposed(by: self.disposeBag)
    }
    
    func itemsCount() -> Int {
        return DAO.fetchCount(Good.self)
    }
    
    func getItem(forIndex: IndexPath) -> Good? {
        return DAO.fetchOne(Good.self, sort: [NSSortDescriptor(key: "name", ascending: true)], index: forIndex.row)
    }
    
    func deleteItem(good: Good) {
        DAO.performAsync(updates: {context -> Void in
            context.delete(good)
        }).observeOn(MainScheduler.asyncInstance).subscribe(onNext: {[weak self] in
            self?.onUpdate?()
        }).disposed(by: self.disposeBag)
    }
}
