//
//  ShoppingListsListModel.swift
//  ShoppingManiac
//
//  Created by Dmitry Matyushkin on 09/05/2018.
//  Copyright © 2018 Dmitry Matyushkin. All rights reserved.
//

import Foundation
import RxSwift

class ShoppingListsListModel {
    
    let disposeBag = DisposeBag()
    var onUpdate: (() -> Void)?
    
    init() {
        LocalNotifications.newDataAvailable.listen().subscribe(onNext: self.onUpdate ?? {}).disposed(by: self.disposeBag)
    }
    
    func itemsCount() -> Int {
        return DAO.fetchCount(ShoppingList.self, predicate: NSPredicate(format: "isRemoved == false"))
    }
    
    func getItem(forIndex: IndexPath) -> ShoppingList? {
        return DAO.fetchOne(ShoppingList.self, predicate: NSPredicate(format: "isRemoved == false"), sort: [NSSortDescriptor(key: "date", ascending: false)], index: forIndex.row)
    }
    
    func deleteItem(shoppingList: ShoppingList) {
        DAO.performAsync(updates: {context -> Void in
            context.edit(shoppingList)?.isRemoved = true
        }).observeOn(MainScheduler.asyncInstance).subscribe(onNext: {[weak self] in
            guard let self = self else { return }
            self.onUpdate?()
        }).disposed(by: self.disposeBag)
    }
}
