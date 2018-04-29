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
import Hydra
import SwiftyBeaver

class CloudLoader {
    
    class func loadShare(metadata: CKShareMetadata) -> Promise<Void> {
        return Promise<RecordsWrapper>(in: .background, { (resolve, _, _) in
            CloudKitUtils.fetchRecords(recordIds: [metadata.rootRecordID], localDb: false).then({ records in
                SwiftyBeaver.debug("\(records.count) shared list records found")
                resolve(RecordsWrapper(localDb: false, records: records, ownerName: metadata.rootRecordID.zoneID.ownerName))
            })
        }).then(loadListRecords).void
    }
        
    class func loadLists() -> Promise<Void> {
        let lists = CoreStore.fetchAll(From<ShoppingList>().where(Where("isRemote == true")))?.filter({($0.ownerName?.count ?? 0) > 0}) ?? []
        return Promise<Void>.zip(all(lists.map({loadListRecord(list: $0, localDb: false).then(storeListRecord).then(fetchListItems).then(storeListItems).void})).void,
            loadListsFromDatabase(localDb: true).then(loadListRecords).void).void
    }
    
    private class func loadListRecord(list: ShoppingList, localDb: Bool) -> Promise<RecordWrapper> {
        return Promise<RecordWrapper>(in: .background, { (resolve, reject, _) in
            let recordId = CKRecordID(recordName: list.recordid ?? "", zoneID: CloudShare.zone(ownerName: list.ownerName).zoneID)
            CloudKitUtils.fetchRecords(recordIds: [recordId], localDb: localDb).then({ records in
                if records.count == 1 {
                    resolve(RecordWrapper(record: records[0], localDb: localDb, ownerName: list.ownerName))
                } else {
                    reject(CommonError(description: "No items found"))
                }
            })
        })
    }

    private class func loadListsFromDatabase(localDb: Bool) -> Promise<RecordsWrapper> {
        return Promise<RecordsWrapper>(in: .background, { (resolve, _, _) in
            CloudKitUtils.fetchRecordsQuery(recordType: CloudKitUtils.listRecordType, localDb: localDb).then({ records in
                resolve(RecordsWrapper(localDb: localDb, records: records, ownerName: nil))
            })
        })
    }

    private class func loadListRecords(wrapper: RecordsWrapper) -> Promise<[Void]> {
        return all(wrapper.records.map({storeListRecord(wrapper: RecordWrapper(record: $0, localDb: wrapper.localDb, ownerName: wrapper.ownerName)).then(fetchListItems).then(storeListItems).void}))
    }

    private class func storeListRecord(wrapper: RecordWrapper) -> Promise<ShoppingListWrapper> {
        return Promise<ShoppingListWrapper>(in: .background, { (resolve, reject, _) in
            storeListRecord(record: wrapper.record, ownerName: wrapper.ownerName, localDb: wrapper.localDb).then({list in
                let items = wrapper.record["items"] as? [CKReference] ?? []
                resolve(ShoppingListWrapper(localDb: wrapper.localDb, record: wrapper.record, shoppingList: list, items: items, ownerName: wrapper.ownerName))
            }).catch({error in
                reject(error)
            })
        })
    }
    
    private class func storeListRecord(record: CKRecord, ownerName: String?, localDb: Bool) -> Promise<ShoppingList> {
        return Promise<ShoppingList>(in: .background, { (resolve, reject, _) in
            CoreStore.perform(asynchronous: { (transaction) -> ShoppingList in
                let shoppingList: ShoppingList = transaction.fetchOne(From<ShoppingList>().where(Where("recordid == %@", record.recordID.recordName))) ?? transaction.create(Into<ShoppingList>())
                shoppingList.recordid = record.recordID.recordName
                shoppingList.ownerName = ownerName
                shoppingList.name = record["name"] as? String
                shoppingList.isRemote = !localDb
                shoppingList.isRemoved = record["isRemoved"] as? Bool ?? false
                let date = record["date"] as? Date ?? Date()
                shoppingList.date = date.timeIntervalSinceReferenceDate
                SwiftyBeaver.debug("got a list with name \(shoppingList.name ?? "no name") record \(String(describing: record))")
                return shoppingList
            }, completion: {result in
                switch result {
                case .success(let list):
                    resolve(list)
                case .failure(let error):
                    SwiftyBeaver.debug(error.debugDescription)
                    reject(error)
                }
            })
        })
    }

    private class func fetchListItems(wrapper: ShoppingListWrapper) -> Promise<ShoppingListItemsWrapper> {
        return Promise<ShoppingListItemsWrapper>(in: .background, { (resolve, _, _) in
            CloudKitUtils.fetchRecords(recordIds: wrapper.items.map({$0.recordID}), localDb: wrapper.localDb).then({ records in
                resolve(ShoppingListItemsWrapper(localDb: wrapper.localDb, shoppingList: wrapper.shoppingList, record: wrapper.record, items: records, ownerName: wrapper.ownerName))
            })
        })
    }

    private class func storeListItems(wrapper: ShoppingListItemsWrapper) -> Promise<Int> {
        return Promise<Int>(in: .background, { (resolve, _, _) in
            CoreStore.perform(asynchronous: { (transaction)  in
                for record in wrapper.items {
                    let item: ShoppingListItem = transaction.fetchOne(From<ShoppingListItem>().where(Where("recordid == %@", record.recordID.recordName))) ?? transaction.create(Into<ShoppingListItem>())
                    SwiftyBeaver.debug("loading item \(record["goodName"] as? String ?? "no name")")
                    item.recordid = record.recordID.recordName
                    item.list = transaction.edit(wrapper.shoppingList)
                    item.comment = record["comment"] as? String
                    if let name = record["goodName"] as? String {
                        let good = transaction.fetchOne(From<Good>().where(Where("name == %@", name))) ?? transaction.create(Into<Good>())
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
                    if let storeName = record["storeName"] as? String, storeName.count > 0 {
                        let store = transaction.fetchOne(From<Store>().where(Where("name == %@", storeName))) ?? transaction.create(Into<Store>())
                        store.name = storeName
                        item.store = store
                    } else {
                        item.store = nil
                    }
                }
            }, completion: {_ in
                resolve(0)
            })
        })
    }
    
    class func clearRecords() -> Promise<Void> {
        let privateLists = clearRecordsFromDatabase(localDb: true, recordType: CloudKitUtils.listRecordType).then(deleteRecords).void
        let privateItems = clearRecordsFromDatabase(localDb: true, recordType: CloudKitUtils.itemRecordType).then(deleteRecords).void
        return all(privateLists, privateItems).void
    }
    
    private class func clearRecordsFromDatabase(localDb: Bool, recordType: String) -> Promise<RecordsWrapper> {
        return Promise<RecordsWrapper>(in: .background, { (resolve, reject, _) in
            CloudKitUtils.fetchRecordsQuery(recordType: recordType, localDb: localDb).then({ records in
                if records.count > 0 {
                    SwiftyBeaver.debug("\(records.count) records found")
                    resolve(RecordsWrapper(localDb: localDb, records: records, ownerName: nil))
                } else {
                    SwiftyBeaver.debug("no list records found")
                    reject(CommonError(description: "No list records found"))
                }
            })
        })
    }
    
    private class func deleteRecords(wrapper: RecordsWrapper) -> Promise<Int> {
        return CloudKitUtils.deleteRecords(recordIds: wrapper.records.map({$0.recordID}), localDb: wrapper.localDb)
    }
    
    class func fetchChanges(localDb: Bool) -> Promise<Int> {
        return Promise<Int>(in: .background, { (resolve, _, _) in
            CloudKitUtils.fetchDatabaseChanges(localDb: localDb).then({zoneIds in
                CloudKitUtils.fetchZoneChanges(localDb: localDb, zoneIds: zoneIds).then(in: .background, { records in
                    if records.count > 0 {
                        var promises: [Promise<Int>] = []
                        let lists = records.filter({$0.recordType == CloudKitUtils.listRecordType})
                        for list in lists {
                            let items = records.filter({$0.recordType == CloudKitUtils.itemRecordType && $0.parent?.recordID.recordName == list.recordID.recordName})
                            let ownerName = list.recordID.zoneID.ownerName
                            let storePromise = Promise<Int>(in: .background, { (resolve, _, _) in
                                storeListRecord(record: list, ownerName: ownerName, localDb: localDb).then({shoppingList in
                                    let wrapper = ShoppingListItemsWrapper(localDb: localDb, shoppingList: shoppingList, record: list, items: items, ownerName: ownerName)
                                    storeListItems(wrapper: wrapper).then({_ in
                                        resolve(0)
                                    })
                                }).catch({_ in
                                    resolve(0)
                                })
                            })
                            promises.append(storePromise)
                        }
                        all(promises).then({_ in resolve(0)})
                    } else {
                        resolve(0)
                    }
            }).catch({_ in resolve(0)})
            }).catch({_ in resolve(0)})
        })
    }
}
