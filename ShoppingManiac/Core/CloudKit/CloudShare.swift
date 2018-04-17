//
//  CloudShare.swift
//  ShoppingManiac
//
//  Created by Dmitry Matyushkin on 17/04/2018.
//  Copyright © 2018 Dmitry Matyushkin. All rights reserved.
//

import UIKit
import CloudKit

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
    private static let zoneName = "ShareZone"
    private static let listRecordType = "ShoppingList"
    private static let itemRecordType = "ShoppingListItem"
    
    private class func createZone() {
        let recordZone = CKRecordZone(zoneName: zoneName)
        CKContainer.default().privateCloudDatabase.save(recordZone) { (zone, error) in
            if let error = error {
                print("Error saving zone \(error.localizedDescription)")
            }
        }
    }
    
    class func setupUserPermissions() {
        CKContainer.default().accountStatus { (status, error) in
            if let error = error {
                print("CloudKit account error \(error)")
            } else if status == .available {
                CKContainer.default().status(forApplicationPermission: .userDiscoverability, completionHandler: { (status, error) in
                    if let error = error {
                        print("CloudKit discoverability status error \(error)")
                    } else if status == .granted {
                        AppDelegate.discoverabilityStatus = true
                        createZone()
                        print("CloudKit discoverability status ok")
                    } else if status == .initialState {
                        CKContainer.default().requestApplicationPermission(.userDiscoverability, completionHandler: { (status, error) in
                            if let error = error {
                                print("CloudKit discoverability status error \(error)")
                            } else if status == .granted {
                                AppDelegate.discoverabilityStatus = true
                                print("CloudKit discoverability status ok")
                            } else {
                                print("CloudKit discoverability status incorrect")
                            }
                        })
                    } else {
                        print("CloudKit discoverability status incorrect")
                    }
                })
            } else {
                print("CloudKit account status incorrect")
            }
        }
    }
    
    class func shareList(list: ShoppingList) {
        let listRecord = getListRecord(list: list)
        shareRecord(record: listRecord)
    }
    
    class func updateList(list: ShoppingList) {
        let listRecord = getListRecord(list: list)
        updateRecord(record: listRecord)
    }
    
    private class func updateListRecord(record: CKRecord, list: ShoppingList) {
        record["name"] = (list.name ?? "") as CKRecordValue
        record["items"] = list.listItems.map({ CKReference(record: getItemRecord(item: $0), action: .deleteSelf) }) as CKRecordValue
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
    
    private class func getListRecord(list: ShoppingList) -> CKRecord {
        let recordZone = CKRecordZone(zoneName: zoneName)
        if let recordName = list.recordid {
            let recordId = CKRecordID(recordName: recordName, zoneID: recordZone.zoneID)
            let record = CKRecord(recordType: listRecordType, recordID: recordId)
            updateListRecord(record: record, list: list)
            return record
        } else {
            let record = CKRecord(recordType: listRecordType, zoneID: recordZone.zoneID)
            list.setRecordId(recordId: record.recordID.recordName)
            updateListRecord(record: record, list: list)
            return record
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
    
    private class func shareRecord(record: CKRecord) {
        let share = CKShare(rootRecord: record)
        share[CKShareTitleKey] = "Shopping list" as CKRecordValue
        share[CKShareTypeKey] = "org.md.ShoppingManiac" as CKRecordValue
        
        selectUserToShare { identity in
            
            if let recordId = identity.userRecordID {
                CKContainer.default().discoverUserIdentity(withUserRecordID: recordId, completionHandler: { (identity, error) in
                    if let lookupInfo = identity?.lookupInfo {
                        let fetchParticipantOperation = CKFetchShareParticipantsOperation(userIdentityLookupInfos: [lookupInfo])
                        fetchParticipantOperation.fetchShareParticipantsCompletionBlock = { error in
                            if let error = error {
                                AppDelegate.showAlert(title: "Sharing error", message: error.localizedDescription)
                            } else {
                                print("Sharing done successfully")
                            }
                        }
                        fetchParticipantOperation.shareParticipantFetchedBlock = { participant in
                            participant.permission = .readWrite
                            share.addParticipant(participant)
                            let modifyOperation = CKModifyRecordsOperation(recordsToSave: [record, share], recordIDsToDelete: nil)
                            modifyOperation.savePolicy = .ifServerRecordUnchanged
                            modifyOperation.perRecordCompletionBlock = {record, error in
                                if let error = error {
                                    print("Error while saving records \(error.localizedDescription)")
                                }
                            }
                            modifyOperation.modifyRecordsCompletionBlock = { records, recordIds, error in
                                if let error = error {
                                    AppDelegate.showAlert(title: "Sharing error", message: error.localizedDescription)
                                } else {
                                    print("Records modification done successfully")
                                }
                            }
                            CKContainer.default().privateCloudDatabase.add(modifyOperation)
                        }
                        CKContainer.default().add(fetchParticipantOperation)
                    } else {
                        AppDelegate.showAlert(title: "Sharing error", message: "Can't lookup for this user")
                    }
                })
            } else {
                AppDelegate.showAlert(title: "Sharing error", message: "Can't lookup for this user")
            }
        }
    }
    
    private class func selectUserToShare(onDone:@escaping (CKUserIdentity)->()) {
        CKContainer.default().discoverAllIdentities { (identities, error) in
            DispatchQueue.main.async {
                if let identities = identities {
                    let controller = UIAlertController(title: "Sharing", message: "Select user to share with", preferredStyle: .actionSheet)
                    for identity in identities {
                        let action = UIAlertAction(title: identity.fullName, style: .default) { action in
                            onDone(identity)
                        }
                        controller.addAction(action)
                    }
                    let cancelAction = UIAlertAction(title: "Cancel", style: .cancel) { action in
                        
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
    
    private class func updateRecord(record: CKRecord) {
        let modifyOperation = CKModifyRecordsOperation(recordsToSave: [record], recordIDsToDelete: nil)
        modifyOperation.savePolicy = .ifServerRecordUnchanged
        modifyOperation.perRecordCompletionBlock = {record, error in
            if let error = error {
                print("Error while saving records \(error.localizedDescription)")
            }
        }
        modifyOperation.modifyRecordsCompletionBlock = { records, recordIds, error in
            if let error = error {
                print("Error when saving records \(error.localizedDescription)")
            }
        }
        CKContainer.default().privateCloudDatabase.add(modifyOperation)
    }
}
