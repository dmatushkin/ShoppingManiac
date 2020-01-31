//
//  ShoppingListModel.swift
//  ShoppingManiac
//
//  Created by Dmitry Matyushkin on 11/05/2018.
//  Copyright © 2018 Dmitry Matyushkin. All rights reserved.
//

import Foundation
import RxSwift
import CoreStore
import RxCocoa

class ShoppingListModel {
    
    private let cloudShare = CloudShare(cloudKitUtils: CloudKitUtils(operations: CloudKitOperations(), storage: CloudKitTokenStorage()))
    let totalText = BehaviorRelay<String>(value: "")
    
    let disposeBag = DisposeBag()
    weak var delegate: UpdateDelegate?
    
    var shoppingList: ShoppingList!
    var shoppingGroups: [ShoppingGroup] = []
    
    init() {
        LocalNotifications.newDataAvailable.listen().subscribe(onNext: {[weak self] in
            self?.reloadData()
        }).disposed(by: self.disposeBag)
    }
        
    func syncWithCloud() {
        if AppDelegate.discoverabilityStatus && self.shoppingList.recordid != nil {
            self.cloudShare.updateList(list: self.shoppingList).subscribe().disposed(by: self.disposeBag)
        }
    }
    
    func resyncData() {
        self.syncWithCloud()
        self.reloadData()
    }
    
    func setLatestList() {
        if let list = try? CoreStoreDefaults.dataStack.fetchOne(From<ShoppingList>().where(Where("isRemoved == false")).orderBy(.descending(\.date))) {
            self.shoppingList = list
        }
    }
    
    private func processData(transaction: AsynchronousDataTransaction) throws {
        if let list = self.shoppingList {
            let items = try transaction.fetchAll(From<ShoppingListItem>().where(Where("(list = %@ OR (isCrossListItem == true AND purchased == false)) AND isRemoved == false", list)))
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
        CoreStoreDefaults.dataStack.perform(asynchronous: self.processData, completion: {[weak self] _ in
            self?.delegate?.reloadData()
        })
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
        self.resyncData()
    }
    
    func togglePurchased(indexPath: IndexPath) {
        let group = self.shoppingGroups[indexPath.section]
        let item = group.items[indexPath.row]
        
        item.togglePurchased(list: self.shoppingList)
        self.syncWithCloud()
        let sortedItems = self.sortItems(items: group.items)
        var itemFound: Bool = false
        for (idx, sortedItem) in sortedItems.enumerated() where item.objectId == sortedItem.objectId {
            let sortedIndexPath = IndexPath(row: idx, section: indexPath.section)
            itemFound = true
            group.items = sortedItems
            self.delegate?.moveRow(fromPath: indexPath, toPath: sortedIndexPath)
            break
        }
        if itemFound == false {
            group.items = sortedItems
            self.delegate?.reloadData()
        }
    }
}
