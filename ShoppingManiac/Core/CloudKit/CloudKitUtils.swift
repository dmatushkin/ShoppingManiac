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
    
    class func fetchRecords(recordIds: [CKRecord.ID], localDb: Bool) -> Observable<CKRecord> {
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
    
    class func deleteRecords(recordIds: [CKRecord.ID], localDb: Bool) -> Observable<Void> {
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
    
    class func fetchDatabaseChanges(localDb: Bool) -> Observable<ZonesToFetchWrapper> {
        return Observable<ZonesToFetchWrapper>.create { observer in
            let operation = CKFetchDatabaseChangesOperation(previousServerChangeToken: localDb ? UserDefaults.standard.localServerChangeToken : UserDefaults.standard.sharedServerChangeToken)
            var zoneIds: [CKRecordZone.ID] = []
            operation.recordZoneWithIDChangedBlock = { zoneId in
                zoneIds.append(zoneId)
            }
            operation.changeTokenUpdatedBlock = { token in
            }
            operation.qualityOfService = .utility
            operation.fetchAllChanges = true
            operation.fetchDatabaseChangesCompletionBlock = { token, moreComing, error in
                if let error = error {
                    SwiftyBeaver.debug(error.localizedDescription)
                    observer.onError(error)
                } else if let token = token {
                    observer.onNext(ZonesToFetchWrapper(localDb: localDb, token: token, zoneIds: zoneIds))
                    SwiftyBeaver.debug("Update zones request finished")
                    observer.onCompleted()
                } else {
                    let error = CommonError(description: "iCloud token is empty")
                    SwiftyBeaver.debug(error.localizedDescription)
                    observer.onError(error)
                }
            }
            CKContainer.default().database(localDb: localDb).add(operation)
            return Disposables.create()
        }
    }
    
    class func fetchZoneChanges(wrapper: ZonesToFetchWrapper) -> Observable<[CKRecord]> {
        return Observable<[CKRecord]>.create { observer in
            if wrapper.zoneIds.count > 0 {
                var records: [CKRecord] = []
                var optionsByRecordZoneID = [CKRecordZone.ID: CKFetchRecordZoneChangesOperation.ZoneConfiguration]()
                for zoneId in wrapper.zoneIds {
                    let options = CKFetchRecordZoneChangesOperation.ZoneConfiguration()
                    options.previousServerChangeToken = nil // UserDefaults.standard.getZoneChangedToken(zoneName: zoneId.zoneName)
                    optionsByRecordZoneID[zoneId] = options
                }                
                let operation = CKFetchRecordZoneChangesOperation(recordZoneIDs: wrapper.zoneIds, configurationsByRecordZoneID: optionsByRecordZoneID)
                operation.recordChangedBlock = { record in
                    records.append(record)
                }
                operation.recordZoneChangeTokensUpdatedBlock = {zoneId, token, data in
                }
                operation.recordZoneFetchCompletionBlock = { zoneId, changeToken, data, moreComing, error in
                    if let error = error {
                        SwiftyBeaver.debug(error.localizedDescription)
                    } else if let token = changeToken {
                        UserDefaults.standard.setZoneChangeToken(zoneName: zoneId.zoneName, token: token)
                    }
                }
                operation.fetchRecordZoneChangesCompletionBlock = { error in
                    if let error = error {
                        SwiftyBeaver.debug(error.localizedDescription)
                        observer.onError(error)
                    } else {
                        if wrapper.localDb {
                            UserDefaults.standard.localServerChangeToken = wrapper.token
                        } else {
                            UserDefaults.standard.sharedServerChangeToken = wrapper.token
                        }
                        SwiftyBeaver.debug("\(records.count) updated records found")
                        observer.onNext(records)
                        observer.onCompleted()
                    }
                }
                CKContainer.default().database(localDb: wrapper.localDb).add(operation)
            } else {
                observer.onCompleted()
            }
            return Disposables.create()
        }
    }    
}
