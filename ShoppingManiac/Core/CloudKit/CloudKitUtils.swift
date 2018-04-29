//
//  CloudKitUtils.swift
//  ShoppingManiac
//
//  Created by Dmitry Matyushkin on 28/04/2018.
//  Copyright © 2018 Dmitry Matyushkin. All rights reserved.
//

import Foundation
import CloudKit
import Hydra
import SwiftyBeaver

class CloudKitUtils {
    
    static let zoneName = "ShareZone"
    static let listRecordType = "ShoppingList"
    static let itemRecordType = "ShoppingListItem"
    
    class func fetchRecords(recordIds: [CKRecordID], localDb: Bool) -> Promise<[CKRecord]> {
        return Promise<[CKRecord]>(in: .background, { (resolve, reject, _) in
            let operation = CKFetchRecordsOperation(recordIDs: recordIds)
            operation.perRecordCompletionBlock = { record, recordid, error in
                if let error = error {
                    SwiftyBeaver.debug(error.localizedDescription)
                } else {
                    SwiftyBeaver.debug("Successfully loaded record \(recordid?.recordName ?? "no record name")")
                }
            }
            operation.fetchRecordsCompletionBlock = { records, error in
                if let records = records, error == nil {
                    resolve(records.map({$0.value}))
                } else {
                    reject(CommonError(description: "No items found"))
                }
            }            
            operation.qualityOfService = .utility
            CKContainer.default().database(localDb: localDb).add(operation)
        })
    }
    
    class func deleteRecords(recordIds: [CKRecordID], localDb: Bool) -> Promise<Int> {
        return Promise<Int>(in: .background, { (resolve, _, _) in
            let modifyOperation = CKModifyRecordsOperation(recordsToSave: nil, recordIDsToDelete: recordIds)
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
            CKContainer.default().database(localDb: localDb).add(modifyOperation)
        })
    }
    
    class func updateSubscriptions(subscriptions: [CKSubscription], localDb: Bool) -> Promise<Int> {
        return Promise<Int>(in: .background, { (resolve, reject, _) in
            let operation = CKModifySubscriptionsOperation(subscriptionsToSave: subscriptions, subscriptionIDsToDelete: [])
            operation.modifySubscriptionsCompletionBlock = { (_, _, error) in
                if let error = error {
                    reject(error)
                } else {
                    resolve(0)
                }
            }
            operation.qualityOfService = .utility
            CKContainer.default().database(localDb: localDb).add(operation)
        })
    }
    
    class func fetchRecordsQuery(recordType: String, localDb: Bool) -> Promise<[CKRecord]> {
        return Promise<[CKRecord]>(in: .background, { (resolve, _, _) in
            let query = CKQuery(recordType: recordType, predicate: NSPredicate(format: "TRUEPREDICATE", argumentArray: nil))
            let recordZone = CKRecordZone(zoneName: CloudKitUtils.zoneName)
            CKContainer.default().database(localDb: localDb).perform(query, inZoneWith: recordZone.zoneID, completionHandler: { (records, error) in
                if let records = records, error == nil {
                    SwiftyBeaver.debug("\(records.count) list records found")
                    resolve(records)
                } else {
                    SwiftyBeaver.debug("no list records found")
                    resolve([])
                }
            })
        })
    }
    
    class func updateRecords(records: [CKRecord], localDb: Bool) -> Promise<Int> {
        return Promise<Int>(in: .background, { (resolve, reject, _) in
            let modifyOperation = CKModifyRecordsOperation(recordsToSave: records, recordIDsToDelete: nil)
            modifyOperation.savePolicy = .allKeys
            modifyOperation.perRecordCompletionBlock = {record, error in
                if let error = error {
                    SwiftyBeaver.debug("Error while saving records \(error.localizedDescription)")
                } else {
                    SwiftyBeaver.debug("Successfully saved record \(record.recordID.recordName)")
                }
            }
            modifyOperation.modifyRecordsCompletionBlock = { records, recordIds, error in
                if let error = error {
                    AppDelegate.showAlert(title: "Sharing error", message: error.localizedDescription)
                    reject(error)
                } else {
                    SwiftyBeaver.debug("Records modification done successfully")
                    resolve(0)
                }
            }
            CKContainer.default().database(localDb: localDb).add(modifyOperation)
        })
    }
    
    class func fetchDatabaseChanges(localDb: Bool, changeToken: CKServerChangeToken?) -> Promise<[CKRecordZoneID]> {
        return Promise<[CKRecordZoneID]>(in: .background, { (resolve, reject, _) in
            var zoneIds: [CKRecordZoneID] = []
            let operation = CKFetchDatabaseChangesOperation(previousServerChangeToken: changeToken)
            operation.recordZoneWithIDChangedBlock = { zoneId in
                zoneIds.append(zoneId)
            }
            operation.changeTokenUpdatedBlock = { token in
                if localDb {
                    UserDefaults.standard.localServerChangeToken = token
                } else {
                    UserDefaults.standard.sharedServerChangeToken = token
                }
            }
            operation.qualityOfService = .utility
            operation.fetchAllChanges = true
            operation.fetchDatabaseChangesCompletionBlock = { token, moreComing, error in
                if let error = error {
                    SwiftyBeaver.debug(error.localizedDescription)
                    reject(error)
                } else {
                    SwiftyBeaver.debug("\(zoneIds.count) updated zones found")
                    resolve(zoneIds)
                }
            }
            CKContainer.default().database(localDb: localDb).add(operation)
        })
    }
    
    class func fetchZoneChanges(localDb: Bool, zoneIds: [CKRecordZoneID], changeToken: CKServerChangeToken?) -> Promise<[CKRecord]> {
        return Promise<[CKRecord]>(in: .background, { (resolve, reject, _) in
            if zoneIds.count > 0 {
                var records: [CKRecord] = []
                var optionsByRecordZoneID = [CKRecordZoneID: CKFetchRecordZoneChangesOptions]()
                for zoneId in zoneIds {
                    let options = CKFetchRecordZoneChangesOptions()
                    options.previousServerChangeToken = changeToken
                    optionsByRecordZoneID[zoneId] = options
                }
                let operation = CKFetchRecordZoneChangesOperation(recordZoneIDs: zoneIds, optionsByRecordZoneID: optionsByRecordZoneID)
                operation.recordChangedBlock = { record in
                    records.append(record)
                }
                operation.recordZoneFetchCompletionBlock = { zoneId, changeToken, data, moreComing, error in
                    if let error = error {
                        SwiftyBeaver.debug(error.localizedDescription)
                    }
                }
                operation.fetchRecordZoneChangesCompletionBlock = { error in
                    if let error = error {
                        SwiftyBeaver.debug(error.localizedDescription)
                        reject(error)
                    } else {
                        SwiftyBeaver.debug("\(records.count) updated records found")
                        resolve(records)
                    }
                }
                CKContainer.default().database(localDb: localDb).add(operation)
            } else {
                resolve([])
            }
        })
    }
}
