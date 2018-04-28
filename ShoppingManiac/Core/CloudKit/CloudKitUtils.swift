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
            let recordZone = CKRecordZone(zoneName: CloudShare.zoneName)
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
}
