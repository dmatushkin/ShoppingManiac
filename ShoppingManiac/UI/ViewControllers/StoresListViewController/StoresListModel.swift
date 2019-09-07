//
//  StoresListModel.swift
//  ShoppingManiac
//
//  Created by Dmitry Matyushkin on 12/05/2018.
//  Copyright © 2018 Dmitry Matyushkin. All rights reserved.
//

import Foundation
import CoreData
import RxSwift
import RxCocoa

class StoresListModel {
    
    let disposeBag = DisposeBag()
    var onUpdate: (() -> Void)?
    
    init() {
        LocalNotifications.newDataAvailable.listen().subscribe(onNext: self.onUpdate ?? {}).disposed(by: self.disposeBag)
    }
        
    func itemsCount() -> Int {
        return DAO.fetchCount(Store.self)
    }
    
    func getItem(forIndex: IndexPath) -> Store? {
        return DAO.fetchOne(Store.self, sort: [NSSortDescriptor(key: "name", ascending: true)], index: forIndex.row)
    }
    
    func deleteItem(item: Store) {
        DAO.performAsync(updates: {context -> Void in
            context.delete(item)
        }).observeOn(MainScheduler.asyncInstance).subscribe(onNext: {[weak self] in
            self?.onUpdate?()
        }).disposed(by: self.disposeBag)
    }
}
