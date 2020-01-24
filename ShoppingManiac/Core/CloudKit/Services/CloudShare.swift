//
//  CloudShare.swift
//  ShoppingManiac
//
//  Created by Dmitry Matyushkin on 17/04/2018.
//  Copyright © 2018 Dmitry Matyushkin. All rights reserved.
//

import UIKit
import CloudKit
import CoreStore
import SwiftyBeaver
import RxSwift

class CloudShare {
    
    private static let cloudKitUtils = CloudKitUtils(operations: CloudKitOperations(), storage: CloudKitTokenStorage())
    
    private init() {}

    class func setupUserPermissions() {
        CKContainer.default().accountStatus { (status, error) in
            if let error = error {
                SwiftyBeaver.debug("CloudKit account error \(error)")
            } else if status == .available {
                CKContainer.default().status(forApplicationPermission: .userDiscoverability, completionHandler: { (status, error) in
                    if let error = error {
                        SwiftyBeaver.debug("CloudKit discoverability status error \(error)")
                    } else if status == .granted {
                        AppDelegate.discoverabilityStatus = true
                        createZone()
                        SwiftyBeaver.debug("CloudKit discoverability status ok")
                    } else if status == .initialState {
                        CKContainer.default().requestApplicationPermission(.userDiscoverability, completionHandler: { (status, error) in
                            if let error = error {
                                SwiftyBeaver.debug("CloudKit discoverability status error \(error)")
                            } else if status == .granted {
                                AppDelegate.discoverabilityStatus = true
                                createZone()
                                SwiftyBeaver.debug("CloudKit discoverability status ok")
                            } else {
                                SwiftyBeaver.debug("CloudKit discoverability status incorrect")
                            }
                        })
                    } else {
                        SwiftyBeaver.debug("CloudKit discoverability status incorrect")
                    }
                })
            } else {
                SwiftyBeaver.debug("CloudKit account status incorrect")
            }
        }
    }

    class func shareList(list: ShoppingList) -> Observable<CKShare> {
        return getListWrapper(list: list).flatMap(createShare)
    }

    class func updateList(list: ShoppingList) -> Observable<Void> {
        return getListWrapper(list: list).flatMap(updateRecord)
    }
    
    private class func createShare(wrapper: ShoppingListItemsWrapper) -> Observable<CKShare> {
        return Observable<CKShare>.create { observer in
            let share = CKShare(rootRecord: wrapper.record)
            share[CKShare.SystemFieldKey.title] = "Shopping list" as CKRecordValue
            share[CKShare.SystemFieldKey.shareType] = "org.md.ShoppingManiac" as CKRecordValue
            share.publicPermission = .readWrite
            
            let recordsToUpdate = [wrapper.record, share]
            
            let disposable = cloudKitUtils.updateRecords(records: recordsToUpdate, localDb: true)
                .concat(cloudKitUtils.updateRecords(records: wrapper.items, localDb: true))
                .subscribe(onError: {error in
                    observer.onError(error)
            }, onCompleted: {
                observer.onNext(share)
                observer.onCompleted()
            })
            return Disposables.create {
                disposable.dispose()
            }
        }
    }
    
    private class func createZone() {
        let recordZone = CKRecordZone(zoneName: CloudKitUtils.zoneName)
        CKContainer.default().privateCloudDatabase.save(recordZone) { (_, error) in
            if let error = error {
                SwiftyBeaver.debug("Error saving zone \(error.localizedDescription)")
            }
        }
    }

    private class func updateListWrapper(record: CKRecord, list: ShoppingList) -> Observable<ShoppingListItemsWrapper> {
        return Observable.from(list.listItems.map({getItemRecord(item: $0)})).merge().toArray().asObservable().map({items in
            for item in items {
                item.setParent(record)
            }
            record["name"] = (list.name ?? "") as CKRecordValue
            record["date"] = Date(timeIntervalSinceReferenceDate: list.date) as CKRecordValue
            record["isRemoved"] = list.isRemoved as CKRecordValue
            record["items"] = items.map({ CKRecord.Reference(record: $0, action: .deleteSelf) }) as CKRecordValue
            return ShoppingListItemsWrapper(localDb: !list.isRemote, shoppingList: list, record: record, items: items, ownerName: list.ownerName)
        })
    }

    private class func updateItemRecord(record: CKRecord, item: ShoppingListItem) {
        record["comment"] = (item.comment ?? "") as CKRecordValue
        record["goodName"] = (item.good?.name ?? "") as CKRecordValue
        record["isWeight"] = item.isWeight as CKRecordValue
        record["price"] = item.price as CKRecordValue
        record["purchased"] = item.purchased as CKRecordValue
        record["quantity"] = item.quantity as CKRecordValue
        record["storeName"] = (item.store?.name ?? "") as CKRecordValue
        record["isRemoved"] = item.isRemoved as CKRecordValue
        record["isCrossListItem"] = item.isCrossListItem as CKRecordValue
    }
    
    private class func zone(ownerName: String?) -> CKRecordZone {
        if let ownerName = ownerName {
            return CKRecordZone(zoneID: CKRecordZone.ID(zoneName: CloudKitUtils.zoneName, ownerName: ownerName))
        } else {
            return CKRecordZone(zoneName: CloudKitUtils.zoneName)
        }
    }

    private class func getListWrapper(list: ShoppingList) -> Observable<ShoppingListItemsWrapper> {
        let recordZone = zone(ownerName: list.ownerName).zoneID
        if let recordName = list.recordid {
            let recordId = CKRecord.ID(recordName: recordName, zoneID: recordZone)
            return cloudKitUtils.fetchRecords(recordIds: [recordId], localDb: !list.isRemote).flatMap({record in
                return updateListWrapper(record: record, list: list)
            })
        } else {
            let recordName = CKRecord.ID().recordName
            let recordId = CKRecord.ID(recordName: recordName, zoneID: recordZone)
            let record = CKRecord(recordType: CloudKitUtils.listRecordType, recordID: recordId)
            list.setRecordId(recordId: recordName)
            return updateListWrapper(record: record, list: list)
        }
    }

    private class func getItemRecord(item: ShoppingListItem) -> Observable<CKRecord> {
        let recordZone = zone(ownerName: item.list?.ownerName).zoneID
        if let recordName = item.recordid {
            let recordId = CKRecord.ID(recordName: recordName, zoneID: recordZone)
            return cloudKitUtils.fetchRecords(recordIds: [recordId], localDb: !(item.list?.isRemote ?? false)).map({record in
                updateItemRecord(record: record, item: item)
                return record
            })
        } else {
            let recordName = CKRecord.ID().recordName
            let recordId = CKRecord.ID(recordName: recordName, zoneID: recordZone)
            let record = CKRecord(recordType: CloudKitUtils.itemRecordType, recordID: recordId)
            item.setRecordId(recordId: recordName)
            updateItemRecord(record: record, item: item)
            return Observable.just(record)
        }
    }
    
    private class func updateRecord(wrapper: ShoppingListItemsWrapper) -> Observable<Void> {
        if let shareRef = wrapper.record.share {
            return cloudKitUtils.fetchRecords(recordIds: [shareRef.recordID], localDb: wrapper.localDb).flatMap({shareRecord in
                return cloudKitUtils.updateRecords(records: [wrapper.record, shareRecord], localDb: wrapper.localDb)
                .concat(cloudKitUtils.updateRecords(records: wrapper.items, localDb: wrapper.localDb))
            })
        } else {
            return cloudKitUtils.updateRecords(records: [wrapper.record], localDb: wrapper.localDb)
            .concat(cloudKitUtils.updateRecords(records: wrapper.items, localDb: wrapper.localDb))
        }
    }
}
