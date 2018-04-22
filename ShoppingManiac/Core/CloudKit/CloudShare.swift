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

    class func shareList(list: ShoppingList) {
        let listRecord = getListRecord(list: list, database: CKContainer.default().privateCloudDatabase)
        shareRecord(list: listRecord)
    }

    class func updateList(list: ShoppingList) {
        let listRecord = getListRecord(list: list, database: CKContainer.default().privateCloudDatabase)
        updateRecord(record: listRecord)
    }

    private class func updateListRecord(record: CKRecord, list: ShoppingList, database: CKDatabase) -> ShoppingListItemsWrapper {
        let items = list.listItems.map({getItemRecord(item: $0)})
        record["name"] = (list.name ?? "") as CKRecordValue
        record["date"] = Date(timeIntervalSinceReferenceDate: list.date) as CKRecordValue
        record["items"] = items.map({ CKReference(record: $0, action: .deleteSelf) }) as CKRecordValue
        return ShoppingListItemsWrapper(database: database, shoppingList: list, record: record, items: items)
    }

    private class func updateItemRecord(record: CKRecord, item: ShoppingListItem) {
        record["comment"] = (item.comment ?? "") as CKRecordValue
        record["goodName"] = (item.good?.name ?? "") as CKRecordValue
        record["isWeight"] = item.isWeight as CKRecordValue
        record["price"] = item.price as CKRecordValue
        record["purchased"] = item.purchased as CKRecordValue
        record["quantity"] = item.quantity as CKRecordValue
        record["storeName"] = (item.store?.name ?? "") as CKRecordValue
        /*if let listRecordId = item.list?.recordid {
            record["list"] = CKReference(recordID: CKRecordID(recordName: listRecordId, zoneID: record.recordID.zoneID), action: .deleteSelf)
        }*/
    }

    private class func getListRecord(list: ShoppingList, database: CKDatabase) -> ShoppingListItemsWrapper {
        let recordZone = CKRecordZone(zoneName: zoneName)
        if let recordName = list.recordid {
            let recordId = CKRecordID(recordName: recordName, zoneID: recordZone.zoneID)
            let record = CKRecord(recordType: listRecordType, recordID: recordId)
            return updateListRecord(record: record, list: list, database: database)
        } else {
            let record = CKRecord(recordType: listRecordType, zoneID: recordZone.zoneID)
            list.setRecordId(recordId: record.recordID.recordName)
            return updateListRecord(record: record, list: list, database: database)
        }
    }

    private class func getItemRecord(item: ShoppingListItem) -> CKRecord {
        let recordZone = CKRecordZone(zoneName: zoneName)
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

    private class func shareRecord(list: ShoppingListItemsWrapper) {
        selectUserToShare { identity in
            if let recordId = identity.userRecordID {
                CKContainer.default().discoverUserIdentity(withUserRecordID: recordId, completionHandler: { (identity, error) in
                    if let lookupInfo = identity?.lookupInfo, error == nil {
                        shareRecord(list: list, toUser: lookupInfo)
                    } else {
                        AppDelegate.showAlert(title: "Sharing error", message: "Can't lookup for this user")
                    }
                })
            } else {
                AppDelegate.showAlert(title: "Sharing error", message: "Can't lookup for this user")
            }
        }
    }
    
    private class func shareRecord(list: ShoppingListItemsWrapper, toUser lookupInfo: CKUserIdentityLookupInfo) {
        let share = CKShare(rootRecord: list.record)
        share[CKShareTitleKey] = "Shopping list" as CKRecordValue
        share[CKShareTypeKey] = "org.md.ShoppingManiac" as CKRecordValue
        let fetchParticipantOperation = CKFetchShareParticipantsOperation(userIdentityLookupInfos: [lookupInfo])
        fetchParticipantOperation.fetchShareParticipantsCompletionBlock = { error in
            if let error = error {
                AppDelegate.showAlert(title: "Sharing error", message: error.localizedDescription)
            } else {
                SwiftyBeaver.debug("Sharing done successfully")
            }
        }
        fetchParticipantOperation.shareParticipantFetchedBlock = { participant in
            participant.permission = .readWrite
            share.addParticipant(participant)
            var recordsToUpdate = [list.record, share]
            recordsToUpdate.append(contentsOf: list.items)
            let modifyOperation = CKModifyRecordsOperation(recordsToSave: recordsToUpdate, recordIDsToDelete: nil)
            modifyOperation.savePolicy = .ifServerRecordUnchanged
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
                } else {
                    SwiftyBeaver.debug("Records modification done successfully")
                    if let items = list.record["items"] as? [CKReference] {
                        for item in items {
                            SwiftyBeaver.debug("list has reference to \(item.recordID.recordName)")
                        }
                    }
                }
            }
            CKContainer.default().privateCloudDatabase.add(modifyOperation)
        }
        CKContainer.default().add(fetchParticipantOperation)
    }

    private class func selectUserToShare(onDone:@escaping (CKUserIdentity) -> Void) {
        CKContainer.default().discoverAllIdentities { (identities, error) in
            DispatchQueue.main.async {
                if let identities = identities {
                    let controller = UIAlertController(title: "Sharing", message: "Select user to share with", preferredStyle: .actionSheet)
                    for identity in identities {
                        let action = UIAlertAction(title: identity.fullName, style: .default) { _ in
                            onDone(identity)
                        }
                        controller.addAction(action)
                    }
                    let cancelAction = UIAlertAction(title: "Cancel", style: .cancel) { _ in

                    }
                    controller.addAction(cancelAction)
                    AppDelegate.topViewController()?.present(controller, animated: true, completion: nil)
                } else if let error = error {
                    AppDelegate.showAlert(title: "Sharing error", message: error.localizedDescription)
                } else {
                    AppDelegate.showAlert(title: "Sharing error", message: "Error getting users to share with")
                }
            }
        }
    }

    private class func updateRecord(record: ShoppingListItemsWrapper) {
        var recordsToSave = [record.record]
        recordsToSave.append(contentsOf: record.items)
        let modifyOperation = CKModifyRecordsOperation(recordsToSave: recordsToSave, recordIDsToDelete: nil)
        modifyOperation.savePolicy = .ifServerRecordUnchanged
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
        }
        CKContainer.default().privateCloudDatabase.add(modifyOperation)
    }        
}
