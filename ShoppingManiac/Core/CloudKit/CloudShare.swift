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

    private class func createZone() {
        let recordZone = CKRecordZone(zoneName: CloudKitUtils.zoneName)
        CKContainer.default().privateCloudDatabase.save(recordZone) { (_, error) in
            if let error = error {
                SwiftyBeaver.debug("Error saving zone \(error.localizedDescription)")
            }
        }
    }

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

    class func shareList(list: ShoppingList) -> ShoppingListItemsWrapper {
        return getListWrapper(list: list)
    }

    class func updateList(list: ShoppingList) -> Observable<Void> {
        let listRecord = getListWrapper(list: list)
        return updateRecord(wrapper: listRecord)
    }

    private class func updateListWrapper(record: CKRecord, list: ShoppingList) -> ShoppingListItemsWrapper {
        let items = list.listItems.map({getItemRecord(item: $0)})
        for item in items {
            item.setParent(record)
        }
        record["name"] = (list.name ?? "") as CKRecordValue
        record["date"] = Date(timeIntervalSinceReferenceDate: list.date) as CKRecordValue
        record["isRemoved"] = list.isRemoved as CKRecordValue
        record["items"] = items.map({ CKRecord.Reference(record: $0, action: .deleteSelf) }) as CKRecordValue
        return ShoppingListItemsWrapper(localDb: !list.isRemote, shoppingList: list, record: record, items: items, ownerName: list.ownerName)
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
    
    class func zone(ownerName: String?) -> CKRecordZone {
        if let ownerName = ownerName {
            return CKRecordZone(zoneID: CKRecordZone.ID(zoneName: CloudKitUtils.zoneName, ownerName: ownerName))
        } else {
            return CKRecordZone(zoneName: CloudKitUtils.zoneName)
        }
    }

    class func getListWrapper(list: ShoppingList) -> ShoppingListItemsWrapper {
        let recordName = list.recordid ?? CKRecord.ID().recordName
        let recordId = CKRecord.ID(recordName: recordName, zoneID: zone(ownerName: list.ownerName).zoneID)
        let record = CKRecord(recordType: CloudKitUtils.listRecordType, recordID: recordId)
        list.setRecordId(recordId: recordName)
        return updateListWrapper(record: record, list: list)
    }

    class func getItemRecord(item: ShoppingListItem) -> CKRecord {
        let recordZone = zone(ownerName: item.list?.ownerName)
        let recordName = item.recordid ?? CKRecord.ID().recordName
        let recordId = CKRecord.ID(recordName: recordName, zoneID: recordZone.zoneID)
        let record = CKRecord(recordType: CloudKitUtils.itemRecordType, recordID: recordId)
        item.setRecordId(recordId: recordName)
        updateItemRecord(record: record, item: item)
        return record
    }
    
    private class func updateRecord(wrapper: ShoppingListItemsWrapper) -> Observable<Void> {
        if let shareRef = wrapper.record.share {
            return CloudKitUtils.fetchRecords(recordIds: [shareRef.recordID], localDb: wrapper.localDb).flatMap({shareRecord in                
                return CloudKitUtils.updateRecords(records: [wrapper.record, shareRecord], localDb: wrapper.localDb)
                .concat(CloudKitUtils.updateRecords(records: wrapper.items, localDb: wrapper.localDb))
            })
        } else {
            return CloudKitUtils.updateRecords(records: [wrapper.record], localDb: wrapper.localDb)
            .concat(CloudKitUtils.updateRecords(records: wrapper.items, localDb: wrapper.localDb))
        }
    }
        
    class func createShare(wrapper: ShoppingListItemsWrapper) -> Observable<CKShare> {
        return Observable<CKShare>.create { observer in
            let share = CKShare(rootRecord: wrapper.record)
            share[CKShare.SystemFieldKey.title] = "Shopping list" as CKRecordValue
            share[CKShare.SystemFieldKey.shareType] = "org.md.ShoppingManiac" as CKRecordValue
            share.publicPermission = .readWrite
            
            let recordsToUpdate = [wrapper.record, share]
            
            let disposable = CloudKitUtils.updateRecords(records: recordsToUpdate, localDb: true)
                .concat(CloudKitUtils.updateRecords(records: wrapper.items, localDb: true))
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
}
