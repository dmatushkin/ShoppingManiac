//
//  CloudLoader.swift
//  ShoppingManiac
//
//  Created by Dmitry Matyushkin on 21/04/2018.
//  Copyright © 2018 Dmitry Matyushkin. All rights reserved.
//

import Foundation
import CloudKit
import CoreData
import SwiftyBeaver
import RxSwift

class CloudLoader {
    
    class func loadShare(metadata: CKShare.Metadata) -> Observable<ShoppingList> {
        return CloudKitUtils.fetchRecords(recordIds: [metadata.rootRecordID], localDb: false)
            .map({RecordWrapper(record: $0, localDb: false, ownerName: metadata.rootRecordID.zoneID.ownerName)})
            .flatMap(storeListRecord)
            .flatMap(fetchListItems)
            .flatMap(storeListItems)
    }
    
    private class func storeListRecord(recordWrapper: RecordWrapper) -> Observable<ShoppingListWrapper> {
        return DAO.performAsync(updates: {context -> ShoppingList in
            let shoppingList = context.fetchOne(ShoppingList.self, predicate: NSPredicate(format: "recordid == %@", recordWrapper.record.recordID.recordName)) ?? context.create()
            shoppingList.recordid = recordWrapper.record.recordID.recordName
            shoppingList.ownerName = recordWrapper.ownerName
            shoppingList.name = recordWrapper.record["name"] as? String
            shoppingList.isRemote = !recordWrapper.localDb
            shoppingList.isRemoved = recordWrapper.record["isRemoved"] as? Bool ?? false
            let date = recordWrapper.record["date"] as? Date ?? Date()
            shoppingList.date = date.timeIntervalSinceReferenceDate
            SwiftyBeaver.debug("got a list with name \(shoppingList.name ?? "no name") record \(String(describing: recordWrapper.record))")
            return shoppingList
        }).map({list -> ShoppingListWrapper in
            let items = recordWrapper.record["items"] as? [CKRecord.Reference] ?? []
            return ShoppingListWrapper(localDb: recordWrapper.localDb, record: recordWrapper.record, shoppingList: list, items: items, ownerName: recordWrapper.ownerName)
        })
    }
    
    private class func fetchListItems(wrapper: ShoppingListWrapper) -> Observable<ShoppingListItemsWrapper> {
        return CloudKitUtils.fetchRecords(recordIds: wrapper.items.map({$0.recordID}), localDb: wrapper.localDb).toArray().asObservable()
            .map({ShoppingListItemsWrapper(localDb: wrapper.localDb, shoppingList: wrapper.shoppingList, record: wrapper.record, items: $0, ownerName: wrapper.ownerName)})
    }

    private class func storeListItems(wrapper: ShoppingListItemsWrapper) -> Observable<ShoppingList> {
        return DAO.performAsync(updates: {context -> Void in
            for record in wrapper.items {
                let item = context.fetchOne(ShoppingListItem.self, predicate: NSPredicate(format: "recordid == %@", record.recordID.recordName)) ?? context.create()
                SwiftyBeaver.debug("loading item \(record["goodName"] as? String ?? "no name")")
                item.recordid = record.recordID.recordName
                item.list = context.edit(wrapper.shoppingList)
                item.comment = record["comment"] as? String
                if let name = record["goodName"] as? String {
                    let good = context.fetchOne(Good.self, predicate: NSPredicate(format: "name == %@", name)) ?? context.create()
                    good.name = name
                    item.good = good
                } else {
                    item.good = nil
                }
                item.isWeight = record["isWeight"] as? Bool ?? false
                item.price = record["price"] as? Float ?? 0
                item.purchased = record["purchased"] as? Bool ?? false
                item.quantity = record["quantity"] as? Float ?? 1
                item.isRemoved = record["isRemoved"] as? Bool ?? false
                item.isCrossListItem = record["isCrossListItem"] as? Bool ?? false
                if let storeName = record["storeName"] as? String, storeName.count > 0 {
                    let store = context.fetchOne(Store.self, predicate: NSPredicate(format: "name == %@", storeName)) ?? context.create()
                    store.name = storeName
                    item.store = store
                } else {
                    item.store = nil
                }
            }
        }).map({ wrapper.shoppingList })
    }

    class func fetchChanges(localDb: Bool) -> Observable<Void> {
        return CloudKitUtils.fetchDatabaseChanges(localDb: localDb).toArray().asObservable()
            .flatMap({(zoneIds: [CKRecordZone.ID]) -> Observable<[CKRecord]> in
                CloudKitUtils.fetchZoneChanges(localDb: localDb, zoneIds: zoneIds)
            }).flatMap({ records in
                processChangesRecords(records: records, localDb: localDb)
            })
    }
    
    private class func processChangesRecords(records: [CKRecord], localDb: Bool) -> Observable<Void> {
        if records.count > 0 {
            let lists = records.filter({$0.recordType == CloudKitUtils.listRecordType}).map({processChangesList(listRecord: $0, allRecords: records, localDb: localDb)})
            return Observable.merge(lists)
        } else {
            return Observable<Void>.empty()
        }
    }
    
    private class func processChangesList(listRecord: CKRecord, allRecords: [CKRecord], localDb: Bool) -> Observable<Void> {
        let items = allRecords.filter({$0.recordType == CloudKitUtils.itemRecordType && $0.parent?.recordID.recordName == listRecord.recordID.recordName})
        let ownerName = listRecord.recordID.zoneID.ownerName
        let wrapper = RecordWrapper(record: listRecord, localDb: localDb, ownerName: ownerName)
        return storeListRecord(recordWrapper: wrapper)
            .map({ShoppingListItemsWrapper(localDb: localDb, shoppingList: $0.shoppingList, record: listRecord, items: items, ownerName: ownerName)})
            .flatMap(storeListItems).flatMap({_ in Observable<Void>.empty()})
    }
}
