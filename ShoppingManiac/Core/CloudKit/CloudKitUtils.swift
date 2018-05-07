//
//  CloudKitUtils.swift
//  ShoppingManiac
//
//  Created by Dmitry Matyushkin on 28/04/2018.
//  Copyright © 2018 Dmitry Matyushkin. All rights reserved.
//

import Foundation
import CloudKit
import SwiftyBeaver
import RxSwift

class CloudKitUtils {
    
    static let zoneName = "ShareZone"
    static let listRecordType = "ShoppingList"
    static let itemRecordType = "ShoppingListItem"
    
    class func fetchRecords(recordIds: [CKRecordID], localDb: Bool) -> Observable<CKRecord> {
        return Observable<CKRecord>.create { observer in
            let operation = CKFetchRecordsOperation(recordIDs: recordIds)
            operation.perRecordCompletionBlock = { record, recordid, error in
                if let error = error {
                    SwiftyBeaver.debug(error.localizedDescription)
                } else if let record = record {
                    SwiftyBeaver.debug("Successfully loaded record \(recordid?.recordName ?? "no record name")")
                    observer.onNext(record)
                }
            }
            operation.fetchRecordsCompletionBlock = { _, error in
                if let error = error {
                    observer.onError(error)
                } else {
                    observer.onCompleted()
                }
            }
            operation.qualityOfService = .utility
            CKContainer.default().database(localDb: localDb).add(operation)
            
            return Disposables.create()
        }
    }
    
    class func deleteRecords(recordIds: [CKRecordID], localDb: Bool) -> Observable<Void> {
        return Observable<Void>.create { observer in
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
                observer.onCompleted()
            }
            CKContainer.default().database(localDb: localDb).add(modifyOperation)
            
            return Disposables.create()
        }
    }
    
    class func updateSubscriptions(subscriptions: [CKSubscription], localDb: Bool) -> Observable<Void> {
        return Observable<Void>.create { observer in
            let operation = CKModifySubscriptionsOperation(subscriptionsToSave: subscriptions, subscriptionIDsToDelete: [])
            operation.modifySubscriptionsCompletionBlock = { (_, _, error) in
                if let error = error {
                    SwiftyBeaver.error(error.localizedDescription)
                    observer.onCompleted()
                    //observer.onError(error)
                } else {
                    observer.onCompleted()
                }
            }
            operation.qualityOfService = .utility
            CKContainer.default().database(localDb: localDb).add(operation)
            
            return Disposables.create()
        }
    }
    
    class func fetchRecordsQuery(recordType: String, localDb: Bool) -> Observable<[CKRecord]> {
        return Observable<[CKRecord]>.create { observer in
            let query = CKQuery(recordType: recordType, predicate: NSPredicate(format: "TRUEPREDICATE", argumentArray: nil))
            let recordZone = CKRecordZone(zoneName: CloudKitUtils.zoneName)
            CKContainer.default().database(localDb: localDb).perform(query, inZoneWith: recordZone.zoneID, completionHandler: { (records, error) in
                if let records = records, error == nil {
                    SwiftyBeaver.debug("\(records.count) list records found")
                    observer.onNext(records)
                    observer.onCompleted()
                } else {
                    SwiftyBeaver.debug("no list records found")
                    observer.onCompleted()
                }
            })
            return Disposables.create()
        }
    }
    
    class func updateRecords(records: [CKRecord], localDb: Bool) -> Observable<Void> {
        return Observable<Void>.create { observer in
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
                    observer.onError(error)
                } else {
                    SwiftyBeaver.debug("Records modification done successfully")
                    observer.onCompleted()
                }
            }
            CKContainer.default().database(localDb: localDb).add(modifyOperation)
            return Disposables.create()
        }
    }
    
    class func fetchDatabaseChanges(localDb: Bool) -> Observable<CKRecordZoneID> {
        return Observable<CKRecordZoneID>.create { observer in
            let operation = CKFetchDatabaseChangesOperation(previousServerChangeToken: localDb ? UserDefaults.standard.localServerChangeToken : UserDefaults.standard.sharedServerChangeToken)
            operation.recordZoneWithIDChangedBlock = { zoneId in
                observer.onNext(zoneId)
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
                    observer.onError(error)
                } else {
                    SwiftyBeaver.debug("Update zones request finished")
                    observer.onCompleted()
                }
            }
            CKContainer.default().database(localDb: localDb).add(operation)
            return Disposables.create()
        }
    }
    
    class func fetchZoneChanges(localDb: Bool, zoneIds: [CKRecordZoneID]) -> Observable<[CKRecord]> {
        return Observable<[CKRecord]>.create { observer in
            if zoneIds.count > 0 {
                var records: [CKRecord] = []
                var optionsByRecordZoneID = [CKRecordZoneID: CKFetchRecordZoneChangesOptions]()
                for zoneId in zoneIds {
                    let options = CKFetchRecordZoneChangesOptions()
                    options.previousServerChangeToken = UserDefaults.standard.getZoneChangedToken(zoneName: zoneId.zoneName)
                    optionsByRecordZoneID[zoneId] = options
                }
                let operation = CKFetchRecordZoneChangesOperation(recordZoneIDs: zoneIds, optionsByRecordZoneID: optionsByRecordZoneID)
                operation.recordChangedBlock = { record in
                    records.append(record)
                }
                operation.recordZoneChangeTokensUpdatedBlock = {zoneId, token, data in
                    UserDefaults.standard.setZoneChangeToken(zoneName: zoneId.zoneName, token: token)
                }
                operation.recordZoneFetchCompletionBlock = { zoneId, changeToken, data, moreComing, error in
                    if let error = error {
                        SwiftyBeaver.debug(error.localizedDescription)
                    }
                }
                operation.fetchRecordZoneChangesCompletionBlock = { error in
                    if let error = error {
                        SwiftyBeaver.debug(error.localizedDescription)
                        observer.onError(error)
                    } else {
                        SwiftyBeaver.debug("\(records.count) updated records found")
                        observer.onNext(records)
                        observer.onCompleted()
                    }
                }
                CKContainer.default().database(localDb: localDb).add(operation)
            } else {
                observer.onCompleted()
            }
            return Disposables.create()
        }
    }    
}
