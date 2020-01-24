//
//  CloudLoader.swift
//  ShoppingManiac
//
//  Created by Dmitry Matyushkin on 21/04/2018.
//  Copyright © 2018 Dmitry Matyushkin. All rights reserved.
//

import Foundation
import CloudKit
import CoreStore
import SwiftyBeaver
import RxSwift

class CloudLoader {
    
    private static let cloudKitUtils = CloudKitUtils(operations: CloudKitOperations(), storage: CloudKitTokenStorage())
    
    class func loadShare(metadata: CKShare.Metadata) -> Observable<ShoppingList> {
        return cloudKitUtils.fetchRecords(recordIds: [metadata.rootRecordID], localDb: false)
            .map({RecordWrapper(record: $0, localDb: false, ownerName: metadata.rootRecordID.zoneID.ownerName)})
            .flatMap(storeListRecord)
            .flatMap(fetchListItems)
            .flatMap(storeListItems)
    }
    
    private class func storeListRecord(recordWrapper: RecordWrapper) -> Observable<ShoppingListWrapper> {
        return Observable<ShoppingListWrapper>.create { observer in
            CoreStoreDefaults.dataStack.perform(asynchronous: { (transaction) -> ShoppingList in
                let shoppingList: ShoppingList = try transaction.fetchOne(From<ShoppingList>().where(Where("recordid == %@", recordWrapper.record.recordID.recordName))) ?? transaction.create(Into<ShoppingList>())
                shoppingList.recordid = recordWrapper.record.recordID.recordName
                shoppingList.ownerName = recordWrapper.ownerName
                shoppingList.name = recordWrapper.record["name"] as? String
                shoppingList.isRemote = !recordWrapper.localDb
                shoppingList.isRemoved = recordWrapper.record["isRemoved"] as? Bool ?? false
                let date = recordWrapper.record["date"] as? Date ?? Date()
                shoppingList.date = date.timeIntervalSinceReferenceDate
                SwiftyBeaver.debug("got a list with name \(shoppingList.name ?? "no name") record \(String(describing: recordWrapper.record))")
                return shoppingList
            }, completion: {result in
                switch result {
                case .success(let list):
                    let items = recordWrapper.record["items"] as? [CKRecord.Reference] ?? []
                    observer.onNext(ShoppingListWrapper(localDb: recordWrapper.localDb, record: recordWrapper.record, shoppingList: list, items: items, ownerName: recordWrapper.ownerName))
                    observer.onCompleted()
                case .failure(let error):
                    SwiftyBeaver.debug(error.debugDescription)
                    observer.onError(error)
                }
            })
            return Disposables.create()
        }
    }
    
    private class func fetchListItems(wrapper: ShoppingListWrapper) -> Observable<ShoppingListItemsWrapper> {
        return cloudKitUtils.fetchRecords(recordIds: wrapper.items.map({$0.recordID}), localDb: wrapper.localDb).toArray().asObservable()
            .map({ShoppingListItemsWrapper(localDb: wrapper.localDb, shoppingList: wrapper.shoppingList, record: wrapper.record, items: $0, ownerName: wrapper.ownerName)})
    }

    private class func storeListItems(wrapper: ShoppingListItemsWrapper) -> Observable<ShoppingList> {
        return Observable<ShoppingList>.create { observer in
            CoreStoreDefaults.dataStack.perform(asynchronous: { (transaction)  in
                for record in wrapper.items {
                    let item: ShoppingListItem = try transaction.fetchOne(From<ShoppingListItem>().where(Where("recordid == %@", record.recordID.recordName))) ?? transaction.create(Into<ShoppingListItem>())
                    SwiftyBeaver.debug("loading item \(record["goodName"] as? String ?? "no name")")
                    item.recordid = record.recordID.recordName
                    item.list = transaction.edit(wrapper.shoppingList)
                    item.comment = record["comment"] as? String
                    if let name = record["goodName"] as? String {
                        let good = try transaction.fetchOne(From<Good>().where(Where("name == %@", name))) ?? transaction.create(Into<Good>())
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
                        let store = try transaction.fetchOne(From<Store>().where(Where("name == %@", storeName))) ?? transaction.create(Into<Store>())
                        store.name = storeName
                        item.store = store
                    } else {
                        item.store = nil
                    }
                }
            }, completion: {_ in
                observer.onNext(wrapper.shoppingList)
                observer.onCompleted()
            })
            return Disposables.create()
        }
    }

    class func fetchChanges(localDb: Bool) -> Observable<Void> {
        return cloudKitUtils.fetchDatabaseChanges(localDb: localDb)
            .flatMap(cloudKitUtils.fetchZoneChanges).flatMap({ records in
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
