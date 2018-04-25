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
    
    private static let subscriptionsKey = "cloudKitSubscriptionsDone"
    private static let subscriptionID = "cloudKitSharedDataSubscription"
    
    class func loadShare(metadata: CKShareMetadata) -> Promise<Void> {
        return Promise<RecordsWrapper>(in: .background, { (resolve, reject, _) in
            let operation = CKFetchRecordsOperation(recordIDs: [metadata.rootRecordID])
            operation.fetchRecordsCompletionBlock = { records, error in
                if let records = records, error == nil {
                    
                    SwiftyBeaver.debug("\(records.count) shared list records found")
                    resolve(RecordsWrapper(localDb: false, records: records.map({$0.value}), ownerName: metadata.rootRecordID.zoneID.ownerName))
                } else {
                    SwiftyBeaver.debug("No shared list records found")
                    reject(CommonError(description: "No shared list records found"))
                }
            }
            CKContainer.default().sharedCloudDatabase.add(operation)
        }).then(loadListRecords).void
    }
    
    class func setupSubscriptions() {
        if UserDefaults.standard.bool(forKey: subscriptionsKey) == false {
            all(setupSubscriptions(database: CKContainer.default().sharedCloudDatabase),
                setupSubscriptions(database: CKContainer.default().privateCloudDatabase)
                ).then({_ in
                    UserDefaults.standard.set(true, forKey: subscriptionsKey)
                })
        }
    }
    
    private class func setupSubscriptions(database: CKDatabase) -> Promise<Int> {
        return Promise<Int>(in: .background, { (resolve, reject, _) in
            let listsSubscription = createSubscription(forType: CloudShare.listRecordType)
            let itemsSubscription = createSubscription(forType: CloudShare.itemRecordType)
            
            let operation = CKModifySubscriptionsOperation(subscriptionsToSave: [listsSubscription, itemsSubscription], subscriptionIDsToDelete: [])
            operation.modifySubscriptionsCompletionBlock = { (_, _, error) in
                if let error = error {
                    reject(error)
                } else {
                    resolve(0)
                }
            }
            operation.qualityOfService = .utility
            database.add(operation)
        })
    }
    
    private class func createSubscription(forType type: String) -> CKQuerySubscription {
        let predicate = NSPredicate(value: true)
        let subscription = CKQuerySubscription(recordType: type, predicate: predicate, subscriptionID: subscriptionID, options: [.firesOnRecordCreation, .firesOnRecordDeletion, .firesOnRecordUpdate])
        let notificationInfo = CKNotificationInfo()
        notificationInfo.shouldSendContentAvailable = true
        subscription.notificationInfo = notificationInfo
        return subscription
    }

    class func loadLists() -> Promise<Void> {
        let lists = CoreStore.fetchAll(From<ShoppingList>().where(Where("isRemote == true")))?.filter({($0.ownerName?.count ?? 0) > 0}) ?? []
        return Promise<Void>.zip(all(lists.map({loadLocalLists(list: $0).then(loadListRecord).then(fetchListItems).then(loadListItems).void})).void,
            loadListsFromDatabase(localDb: true).then(loadListRecords).void).void
    }
    
    private class func loadLocalLists(list: ShoppingList) -> Promise<RecordWrapper> {
        return Promise<RecordWrapper>(in: .background, { (resolve, reject, _) in
            let recordId = CKRecordID(recordName: list.recordid ?? "", zoneID: CloudShare.zone(ownerName: list.ownerName).zoneID)
            let operation = CKFetchRecordsOperation(recordIDs: [recordId])
            operation.fetchRecordsCompletionBlock = { records, error in
                if let records = records, records.count == 1, error == nil {
                    resolve(RecordWrapper(record: records.map({$0.value})[0], localDb: false, ownerName: list.ownerName))
                } else {
                    reject(CommonError(description: "No items found"))
                }
            }
            operation.perRecordCompletionBlock = { record, recordid, error in
                if let error = error {
                    SwiftyBeaver.debug(error.localizedDescription)
                } else {
                    SwiftyBeaver.debug("Successfully loaded record \(recordid?.recordName ?? "no record name")")
                }
            }
            operation.qualityOfService = .utility
            CKContainer.default().database(localDb: false).add(operation)
        })
    }

    private class func loadListsFromDatabase(localDb: Bool) -> Promise<RecordsWrapper> {
        return Promise<RecordsWrapper>(in: .background, { (resolve, _, _) in
            let query = CKQuery(recordType: CloudShare.listRecordType, predicate: NSPredicate(format: "TRUEPREDICATE", argumentArray: nil))
            let recordZone = CKRecordZone(zoneName: CloudShare.zoneName)
            CKContainer.default().database(localDb: localDb).perform(query, inZoneWith: recordZone.zoneID, completionHandler: { (records, error) in
                if let records = records, error == nil {
                    SwiftyBeaver.debug("\(records.count) list records found")
                    resolve(RecordsWrapper(localDb: localDb, records: records, ownerName: nil))
                } else {
                    SwiftyBeaver.debug("no list records found")
                    resolve(RecordsWrapper(localDb: localDb, records: [], ownerName: nil))
                }
            })
        })
    }

    private class func loadListRecords(wrapper: RecordsWrapper) -> Promise<[Void]> {
        return all(wrapper.records.map({loadListRecord(wrapper: RecordWrapper(record: $0, localDb: wrapper.localDb, ownerName: wrapper.ownerName)).then(fetchListItems).then(loadListItems).void}))
    }

    private class func loadListRecord(wrapper: RecordWrapper) -> Promise<ShoppingListWrapper> {
        return Promise<ShoppingListWrapper>(in: .background, { (resolve, reject, _) in
            CoreStore.perform(asynchronous: { (transaction) -> ShoppingList in
                let shoppingList: ShoppingList = transaction.fetchOne(From<ShoppingList>().where(Where("recordid == %@", wrapper.record.recordID.recordName))) ?? transaction.create(Into<ShoppingList>())
                shoppingList.recordid = wrapper.record.recordID.recordName
                shoppingList.ownerName = wrapper.ownerName
                shoppingList.name = wrapper.record["name"] as? String
                shoppingList.isRemote = !wrapper.localDb
                let date = wrapper.record["date"] as? Date ?? Date()
                shoppingList.date = date.timeIntervalSinceReferenceDate
                SwiftyBeaver.debug("got a list with name \(shoppingList.name ?? "no name")")
                return shoppingList
            }, completion: {result in
                switch result {
                case .success(let list):
                    let items = wrapper.record["items"] as? [CKReference] ?? []
                    resolve(ShoppingListWrapper(localDb: wrapper.localDb, record: wrapper.record, shoppingList: list, items: items, ownerName: wrapper.ownerName))
                case .failure(let error):
                    SwiftyBeaver.debug(error.debugDescription)
                    reject(error)
                }
            })
        })
    }

    private class func fetchListItems(wrapper: ShoppingListWrapper) -> Promise<ShoppingListItemsWrapper> {
        return Promise<ShoppingListItemsWrapper>(in: .background, { (resolve, reject, _) in
            let operation = CKFetchRecordsOperation(recordIDs: wrapper.items.map({$0.recordID}))
            operation.fetchRecordsCompletionBlock = { records, error in
                if let records = records, error == nil {
                    resolve(ShoppingListItemsWrapper(localDb: wrapper.localDb, shoppingList: wrapper.shoppingList, record: wrapper.record, items: records.map({$0.value}), ownerName: wrapper.ownerName))
                } else {
                    reject(CommonError(description: "No items found"))
                }
            }
            operation.perRecordCompletionBlock = { record, recordid, error in
                if let error = error {
                    SwiftyBeaver.debug(error.localizedDescription)
                } else {
                    SwiftyBeaver.debug("Successfully loaded record \(recordid?.recordName ?? "no record name")")
                }
            }
            operation.qualityOfService = .utility
            CKContainer.default().database(localDb: wrapper.localDb).add(operation)
        })
    }

    private class func loadListItems(wrapper: ShoppingListItemsWrapper) -> Promise<Int> {
        return Promise<Int>(in: .background, { (resolve, _, _) in
            CoreStore.perform(asynchronous: { (transaction)  in
                for record in wrapper.items {
                    let item: ShoppingListItem = transaction.fetchOne(From<ShoppingListItem>().where(Where("recordid == %@", record.recordID.recordName))) ?? transaction.create(Into<ShoppingListItem>())
                    SwiftyBeaver.debug("loading item \(record["goodName"] as? String ?? "no name")")
                    item.recordid = record.recordID.recordName
                    item.list = transaction.fetchExisting(wrapper.shoppingList)
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
    
    class func deleteList(list: ShoppingList) {
        if let listRecordId = list.recordid {
            let recordZone = CloudShare.zone(ownerName: list.ownerName)
            let itemRecordIds = list.listItems.map({$0.recordid}).filter({$0 != nil}).map({$0!})
            var recordIdsToDelete = [CKRecordID(recordName: listRecordId, zoneID: recordZone.zoneID)]
            recordIdsToDelete.append(contentsOf: itemRecordIds.map({CKRecordID(recordName: $0, zoneID: recordZone.zoneID)}))
            deleteRecords(recordIds: recordIdsToDelete, localDb: !list.isRemote)
        }
    }
    
    private class func deleteRecords(recordIds: [CKRecordID], localDb: Bool) {
        let modifyOperation = CKModifyRecordsOperation(recordsToSave: nil, recordIDsToDelete: recordIds)
        modifyOperation.savePolicy = .allKeys
        modifyOperation.perRecordCompletionBlock = {record, error in
            if let error = error {
                SwiftyBeaver.debug("Error while deleting record \(error.localizedDescription)")
            } else {
                SwiftyBeaver.debug("Successfully deleted record \(record.recordID.recordName)")
            }
        }
        modifyOperation.modifyRecordsCompletionBlock = { records, recordIds, error in
            if let error = error {
                SwiftyBeaver.debug("Error when deleting records \(error.localizedDescription)")
            }
        }
        CKContainer.default().database(localDb: localDb).add(modifyOperation)
    }
    
    class func clearRecords() -> Promise<Void> {
        let privateLists = clearRecordsFromDatabase(localDb: true, recordType: CloudShare.listRecordType).then(deleteRecords).void
        let privateItems = clearRecordsFromDatabase(localDb: true, recordType: CloudShare.itemRecordType).then(deleteRecords).void
        return all(privateLists, privateItems).void
    }
    
    private class func clearRecordsFromDatabase(localDb: Bool, recordType: String) -> Promise<RecordsWrapper> {
        return Promise<RecordsWrapper>(in: .background, { (resolve, reject, _) in
            let query = CKQuery(recordType: recordType, predicate: NSPredicate(format: "TRUEPREDICATE", argumentArray: nil))
            let recordZone = CKRecordZone(zoneName: CloudShare.zoneName)
            CKContainer.default().database(localDb: localDb).perform(query, inZoneWith: recordZone.zoneID, completionHandler: { (records, error) in
                if let records = records, error == nil {
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
        return Promise<Int>(in: .background, { (resolve, _, _) in
            let modifyOperation = CKModifyRecordsOperation(recordsToSave: nil, recordIDsToDelete: wrapper.records.map({$0.recordID}))
            modifyOperation.savePolicy = .allKeys
            modifyOperation.perRecordCompletionBlock = {record, error in
                if let error = error {
                    SwiftyBeaver.debug("Error while deleting records \(error.localizedDescription)")
                } else {
                    SwiftyBeaver.debug("Successfully deleted record \(record.recordID.recordName)")
                }
            }
            modifyOperation.modifyRecordsCompletionBlock = { records, recordIds, error in
                if let error = error {
                    SwiftyBeaver.debug("Error when deleting records \(error.localizedDescription)")
                }
                resolve(0)
            }
            CKContainer.default().database(localDb: wrapper.localDb).add(modifyOperation)
        })
    }
}
