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

extension CKUserIdentity {

    var fullName: String {
        if let components = self.nameComponents {
            return "\(components.givenName ?? "") \(components.familyName ?? "")"
        } else {
            return "Unknown"
        }
    }
}

class CloudShare {

    static let lowPriorityQueye = DispatchQueue(label: "dataSharingQueue", qos: .background, attributes: [], autoreleaseFrequency: .inherit, target: nil)
    static let zoneName = "ShareZone"
    static let listRecordType = "ShoppingList"
    static let itemRecordType = "ShoppingListItem"

    private class func createZone() {
        let recordZone = CKRecordZone(zoneName: zoneName)
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
            return CKRecordZone(zoneID: CKRecordZoneID(zoneName: zoneName, ownerName: ownerName))
        } else {
            return CKRecordZone(zoneName: zoneName)
        }
    }

    private class func getListRecord(list: ShoppingList) -> ShoppingListItemsWrapper {
        if let recordName = list.recordid {
            let recordId = CKRecordID(recordName: recordName, zoneID: zone(ownerName: list.ownerName).zoneID)
            let record = CKRecord(recordType: listRecordType, recordID: recordId)
            return updateListRecord(record: record, list: list)
        } else {
            let record = CKRecord(recordType: listRecordType, zoneID: zone(ownerName: list.ownerName).zoneID)
            list.setRecordId(recordId: record.recordID.recordName)
            return updateListRecord(record: record, list: list)
        }
    }

    private class func getItemRecord(item: ShoppingListItem) -> CKRecord {
        let recordZone = zone(ownerName: item.list?.ownerName)
        if let recordName = item.recordid {
            let recordId = CKRecordID(recordName: recordName, zoneID: recordZone.zoneID)
            let record = CKRecord(recordType: itemRecordType, recordID: recordId)
            updateItemRecord(record: record, item: item)
            return record
        } else {
            let record =  CKRecord(recordType: itemRecordType, zoneID: recordZone.zoneID)
            item.setRecordId(recordId: record.recordID.recordName)
            updateItemRecord(record: record, item: item)
            return record
        }
    }
    
    private class func updateRecord(record: ShoppingListItemsWrapper) {
        let recordsToSave = [record.record]
        //recordsToSave.append(contentsOf: record.items)
        let modifyOperation = CKModifyRecordsOperation(recordsToSave: recordsToSave, recordIDsToDelete: nil)
        modifyOperation.savePolicy = .changedKeys
        modifyOperation.perRecordCompletionBlock = {record, error in
            if let error = error {
                SwiftyBeaver.debug("Error while saving records \(error.localizedDescription)")
            } else {
                SwiftyBeaver.debug("Successfully saved record \(record.recordID.recordName)")
            }
        }
        modifyOperation.modifyRecordsCompletionBlock = { records, recordIds, error in
            if let error = error {
                SwiftyBeaver.debug("Error when saving records \(error.localizedDescription)")
            } else {
                updateRecords(wrapper: RecordsWrapper(localDb: !record.shoppingList.isRemote, records: record.items, ownerName: record.ownerName)).then { _ in
                    
                }
            }
        }
        CKContainer.default().database(localDb: record.localDb).add(modifyOperation)
    }
    
    class func updateRecords(wrapper: RecordsWrapper) -> Promise<Error?> {
        return Promise<Error?>(in: .background, { (resolve, _, _) in
            let modifyOperation = CKModifyRecordsOperation(recordsToSave: wrapper.records, recordIDsToDelete: nil)
            modifyOperation.savePolicy = .changedKeys
            modifyOperation.perRecordCompletionBlock = {record, error in
                if let error = error {
                    SwiftyBeaver.debug("Error while saving records \(error.localizedDescription)")
                } else {
                    SwiftyBeaver.debug("Successfully saved record \(record.recordID.recordName)")
                }
            }
            modifyOperation.modifyRecordsCompletionBlock = { records, recordIds, error in
                if let error = error {
                    SwiftyBeaver.debug("Error when saving records \(error.localizedDescription)")
                }
                resolve(error)
            }
            CKContainer.default().database(localDb: wrapper.localDb).add(modifyOperation)
        })
    }
    
    class func createShare(wrapper: ShoppingListItemsWrapper) -> Promise<CKShare> {
        return Promise<CKShare>(in: .background, { (resolve, reject, _) in
            let share = CKShare(rootRecord: wrapper.record)
            share[CKShareTitleKey] = "Shopping list" as CKRecordValue
            share[CKShareTypeKey] = "org.md.ShoppingManiac" as CKRecordValue
            share.publicPermission = .readWrite
            
            let recordsToUpdate = [wrapper.record, share]
            let modifyOperation = CKModifyRecordsOperation(recordsToSave: recordsToUpdate, recordIDsToDelete: nil)
            modifyOperation.savePolicy = .changedKeys
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
                    resolve(share)
                }
            }
            CKContainer.default().privateCloudDatabase.add(modifyOperation)
        })
    }
}
