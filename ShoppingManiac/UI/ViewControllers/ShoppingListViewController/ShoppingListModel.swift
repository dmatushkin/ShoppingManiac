//
//  ShoppingListModel.swift
//  ShoppingManiac
//
//  Created by Dmitry Matyushkin on 11/05/2018.
//  Copyright © 2018 Dmitry Matyushkin. All rights reserved.
//

import Foundation
import RxSwift
import CoreData
import RxCocoa

class ShoppingListModel {
    
    let totalText = BehaviorRelay<String>(value: "")
    
    let disposeBag = DisposeBag()
    var onUpdate: (() -> Void)?
    var moveRow: ((IndexPath, IndexPath) -> Void)?
    
    var shoppingList: ShoppingList!
    var shoppingGroups: [ShoppingGroup] = []
    
    init() {
        LocalNotifications.newDataAvailable.listen().subscribe(onNext: self.onUpdate ?? {}).disposed(by: self.disposeBag)
    }
    
    func setLatestList() {
        if let list = DAO.fetchOne(ShoppingList.self, predicate: NSPredicate(format: "isRemoved == false"), sort: [NSSortDescriptor(key: "date", ascending: false)]) {
            self.shoppingList = list
        }
    }
    
    private func processData(context: NSManagedObjectContext) {
        if let list = self.shoppingList {
            let items: [ShoppingListItem] = context.fetchAll(ShoppingListItem.self, predicate: NSPredicate(format: "(list = %@ OR (isCrossListItem == true AND purchased == false)) AND isRemoved == false", list))
            let totalPrice = items.reduce(0.0) { acc, curr in
                return acc + curr.totalPrice
            }
            var groups: [ShoppingGroup] = []
            for item in items {
                let storeName = item.store?.name
                let storeObjectId = item.store?.objectID
                if let group = groups.filter({ $0.objectId == storeObjectId }).first {
                    group.items.append(GroupItem(shoppingListItem: item))
                } else {
                    let group = ShoppingGroup(name: storeName, objectId: storeObjectId, items: [GroupItem(shoppingListItem: item)])
                    groups.append(group)
                }
            }
            self.shoppingGroups = self.sortGroups(groups: groups)
            self.totalText.accept(String(format: "Total: %.2f", totalPrice))
        }
    }
    
    func reloadData() {
        DAO.performAsync(updates: self.processData).observeOn(MainScheduler.asyncInstance).subscribe(onNext: {[weak self] in
            self?.onUpdate?()
        }).disposed(by: self.disposeBag)
    }
    
    private func sortGroups(groups: [ShoppingGroup]) -> [ShoppingGroup] {
        for group in groups {
            group.items = self.sortItems(items: group.items)
        }
        return groups.sorted(by: {item1, item2 in (item1.groupName ?? "") < (item2.groupName ?? "")})
    }
    
    private func sortItems(items: [GroupItem]) -> [GroupItem] {
        return items.sorted(by: {item1, item2 in item1.lessThan(item: item2) })
    }
    
    func sectionsCount() -> Int {
        return self.shoppingGroups.count
    }
    
    func rowsCount(forSection section: Int) -> Int {
        return self.shoppingGroups[section].items.count
    }
    
    func item(forIndexPath indexPath: IndexPath) -> GroupItem {
        return self.shoppingGroups[indexPath.section].items[indexPath.row]
    }
    
    func sectionTitle(forSection section: Int) -> String? {
        return self.shoppingGroups[section].groupName
    }
    
    func moveItem(from: IndexPath, toGroup: Int) {
        let item = self.item(forIndexPath: from)
        item.moveTo(group: self.shoppingGroups[toGroup])
        self.reloadData()
    }
    
    func togglePurchased(indexPath: IndexPath) {
        let group = self.shoppingGroups[indexPath.section]
        let item = group.items[indexPath.row]
        
        item.togglePurchased(list: self.shoppingList)
        let sortedItems = self.sortItems(items: group.items)
        var itemFound: Bool = false
        for (idx, sortedItem) in sortedItems.enumerated() where item.objectId == sortedItem.objectId {
            let sortedIndexPath = IndexPath(row: idx, section: indexPath.section)
            itemFound = true
            group.items = sortedItems
            self.moveRow?(indexPath, sortedIndexPath)
            break
        }
        if itemFound == false {
            group.items = sortedItems
            self.onUpdate?()
        }
    }
}
