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

class CloudLoader {
    
    private static let subscriptionsKey = "cloudKitSubscriptionsDone"
    private static let subscriptionID = "cloudKitSharedDataSubscription"
    
    class func setupSubscriptions() {
        if UserDefaults.standard.bool(forKey: subscriptionsKey) == false {
            let listsSubscription = createSubscription(forType: CloudShare.listRecordType)
            let itemsSubscription = createSubscription(forType: CloudShare.itemRecordType)
            
            let operation = CKModifySubscriptionsOperation(subscriptionsToSave: [listsSubscription, itemsSubscription], subscriptionIDsToDelete: [])
            operation.modifySubscriptionsCompletionBlock = { (_, _, error) in
                guard error == nil else {
                    return
                }                
                UserDefaults.standard.set(true, forKey: subscriptionsKey)
            }
            operation.qualityOfService = .utility
            
            let container = CKContainer.default()
            let db = container.privateCloudDatabase
            db.add(operation)
        }
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
        return loadListsFromDatabase(database: CKContainer.default().privateCloudDatabase).then(loadListRecords).then({_ in
            loadListsFromDatabase(database: CKContainer.default().sharedCloudDatabase).then(loadListRecords)
        })
    }

    private class func loadListsFromDatabase(database: CKDatabase) -> Promise<RecordsWrapper> {
        return Promise<RecordsWrapper>(in: .background, { (resolve, _, _) in
            let query = CKQuery(recordType: CloudShare.listRecordType, predicate: NSPredicate(format: "TRUEPREDICATE", argumentArray: nil))
            let recordZone = CKRecordZone(zoneName: CloudShare.zoneName)
            print("loading lists from database \(String(describing: database))")
            database.perform(query, inZoneWith: recordZone.zoneID, completionHandler: { (records, error) in
                if let records = records, error == nil {
                    print("\(records.count) list records found")
                    resolve(RecordsWrapper(database: database, records: records))
                } else {
                    print("no list records found")
                    resolve(RecordsWrapper(database: database, records: []))
                }
            })
        })
    }

    private class func loadListRecords(wrapper: RecordsWrapper) -> Promise<[Void]> {
        return all(wrapper.records.map({loadListRecord(wrapper: RecordWrapper(record: $0, database: wrapper.database)).then(fetchListItems).then(loadListItems).void}))
    }

    private class func loadListRecord(wrapper: RecordWrapper) -> Promise<ShoppingListWrapper> {
        return Promise<ShoppingListWrapper>(in: .background, { (resolve, reject, _) in
            CoreStore.perform(asynchronous: { (transaction) -> ShoppingList in
                let shoppingList: ShoppingList = transaction.fetchOne(From<ShoppingList>().where(Where("recordid == %@", wrapper.record.recordID.recordName))) ?? transaction.create(Into<ShoppingList>())
                shoppingList.recordid = wrapper.record.recordID.recordName
                shoppingList.name = wrapper.record["name"] as? String
                let date = wrapper.record["date"] as? Date ?? Date()
                shoppingList.date = date.timeIntervalSinceReferenceDate
                print("got a list with name \(shoppingList.name ?? "no name")")
                return shoppingList
            }, completion: {result in
                switch result {
                case .success(let list):
                    let items = wrapper.record["items"] as? [CKReference] ?? []
                    resolve(ShoppingListWrapper(database: wrapper.database, record: wrapper.record, shoppingList: list, items: items))
                case .failure(let error):
                    print(error.debugDescription)
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
                    resolve(ShoppingListItemsWrapper(database: wrapper.database, shoppingList: wrapper.shoppingList, record: wrapper.record, items: records.map({$0.value})))
                } else {
                    reject(CommonError(description: "No items found"))
                }
            }
            operation.perRecordCompletionBlock = { record, recordid, error in
                if let error = error {
                    print(error.localizedDescription)
                } else {
                    print("Successfully loaded record \(recordid?.recordName ?? "no record name")")
                }
            }
            operation.qualityOfService = .utility
            wrapper.database.add(operation)
        })
    }

    private class func loadListItems(wrapper: ShoppingListItemsWrapper) -> Promise<Int> {
        return Promise<Int>(in: .background, { (resolve, _, _) in
            CoreStore.perform(asynchronous: { (transaction)  in
                for record in wrapper.items {
                    let item: ShoppingListItem = transaction.fetchOne(From<ShoppingListItem>().where(Where("recordid == %@", record.recordID.recordName))) ?? transaction.create(Into<ShoppingListItem>())
                    print("loading item \(record["goodName"] as? String ?? "no name")")
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
    
    class func clearRecords() -> Promise<Void> {
        let privateLists = clearRecordsFromDatabase(database: CKContainer.default().privateCloudDatabase, recordType: CloudShare.listRecordType).then(deleteRecords).void
        let privateItems = clearRecordsFromDatabase(database: CKContainer.default().privateCloudDatabase, recordType: CloudShare.itemRecordType).then(deleteRecords).void
        let sharedLists = clearRecordsFromDatabase(database: CKContainer.default().sharedCloudDatabase, recordType: CloudShare.listRecordType).then(deleteRecords).void
        let sharedItems = clearRecordsFromDatabase(database: CKContainer.default().sharedCloudDatabase, recordType: CloudShare.itemRecordType).then(deleteRecords).void
        return all(privateLists, privateItems, sharedLists, sharedItems).void
    }
    
    private class func clearRecordsFromDatabase(database: CKDatabase, recordType: String) -> Promise<RecordsWrapper> {
        return Promise<RecordsWrapper>(in: .background, { (resolve, reject, _) in
            let query = CKQuery(recordType: recordType, predicate: NSPredicate(format: "TRUEPREDICATE", argumentArray: nil))
            let recordZone = CKRecordZone(zoneName: CloudShare.zoneName)
            print("clearing records of type \(recordType) from database \(String(describing: database))")
            database.perform(query, inZoneWith: recordZone.zoneID, completionHandler: { (records, error) in
                if let records = records, error == nil {
                    print("\(records.count) records found")
                    resolve(RecordsWrapper(database: database, records: records))
                } else {
                    print("no list records found")
                    reject(CommonError(description: "No list records found"))
                }
            })
        })
    }
    
    private class func deleteRecords(wrapper: RecordsWrapper) -> Promise<Int> {
        return Promise<Int>(in: .background, { (resolve, _, _) in
            let modifyOperation = CKModifyRecordsOperation(recordsToSave: nil, recordIDsToDelete: wrapper.records.map({$0.recordID}))
            modifyOperation.savePolicy = .ifServerRecordUnchanged
            modifyOperation.perRecordCompletionBlock = {record, error in
                if let error = error {
                    print("Error while deleting records \(error.localizedDescription)")
                } else {
                    print("Successfully deleted record \(record.recordID.recordName)")
                }
            }
            modifyOperation.modifyRecordsCompletionBlock = { records, recordIds, error in
                if let error = error {
                    print("Error when deleting records \(error.localizedDescription)")
                }
                resolve(0)
            }
            wrapper.database.add(modifyOperation)
        })
    }
}
