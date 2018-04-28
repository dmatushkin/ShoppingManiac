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
import Hydra

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
        return getListRecord(list: list)
    }

    class func updateList(list: ShoppingList) {
        let listRecord = getListRecord(list: list)
        updateRecord(record: listRecord)
    }

    private class func updateListRecord(record: CKRecord, list: ShoppingList) -> ShoppingListItemsWrapper {
        let items = list.listItems.map({getItemRecord(item: $0)})
        for item in items {
            item.setParent(record)
        }
        record["name"] = (list.name ?? "") as CKRecordValue
        record["date"] = Date(timeIntervalSinceReferenceDate: list.date) as CKRecordValue
        record["items"] = items.map({ CKReference(record: $0, action: .deleteSelf) }) as CKRecordValue
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
    }
    
    class func zone(ownerName: String?) -> CKRecordZone {
        if let ownerName = ownerName {
            return CKRecordZone(zoneID: CKRecordZoneID(zoneName: CloudKitUtils.zoneName, ownerName: ownerName))
        } else {
            return CKRecordZone(zoneName: CloudKitUtils.zoneName)
        }
    }

    class func getListRecord(list: ShoppingList) -> ShoppingListItemsWrapper {
        if let recordName = list.recordid {
            let recordId = CKRecordID(recordName: recordName, zoneID: zone(ownerName: list.ownerName).zoneID)
            let record = CKRecord(recordType: CloudKitUtils.listRecordType, recordID: recordId)
            return updateListRecord(record: record, list: list)
        } else {
            let record = CKRecord(recordType: CloudKitUtils.listRecordType, zoneID: zone(ownerName: list.ownerName).zoneID)
            list.setRecordId(recordId: record.recordID.recordName)
            return updateListRecord(record: record, list: list)
        }
    }

    class func getItemRecord(item: ShoppingListItem) -> CKRecord {
        let recordZone = zone(ownerName: item.list?.ownerName)
        if let recordName = item.recordid {
            let recordId = CKRecordID(recordName: recordName, zoneID: recordZone.zoneID)
            let record = CKRecord(recordType: CloudKitUtils.itemRecordType, recordID: recordId)
            updateItemRecord(record: record, item: item)
            return record
        } else {
            let record =  CKRecord(recordType: CloudKitUtils.itemRecordType, zoneID: recordZone.zoneID)
            item.setRecordId(recordId: record.recordID.recordName)
            updateItemRecord(record: record, item: item)
            return record
        }
    }
    
    private class func updateRecord(record: ShoppingListItemsWrapper) {
        CloudKitUtils.updateRecords(records: [record.record], localDb: record.localDb).then({_ in
            updateRecords(wrapper: RecordsWrapper(localDb: !record.shoppingList.isRemote, records: record.items, ownerName: record.ownerName)).then { _ in
            }
        })
    }
    
    class func updateRecords(wrapper: RecordsWrapper) -> Promise<Error?> {
        return Promise<Error?>(in: .background, { (resolve, _, _) in
            CloudKitUtils.updateRecords(records: wrapper.records, localDb: wrapper.localDb).then({_ in
                resolve(nil)
            }).catch({error in
                resolve(error)
            })
        })
    }
    
    class func createShare(wrapper: ShoppingListItemsWrapper) -> Promise<CKShare> {
        return Promise<CKShare>(in: .background, { (resolve, _, _) in
            let share = CKShare(rootRecord: wrapper.record)
            share[CKShareTitleKey] = "Shopping list" as CKRecordValue
            share[CKShareTypeKey] = "org.md.ShoppingManiac" as CKRecordValue
            share.publicPermission = .readWrite
            
            let recordsToUpdate = [wrapper.record, share]
            CloudKitUtils.updateRecords(records: recordsToUpdate, localDb: true).then({_ in
                resolve(share)
            })
        })
    }
}
