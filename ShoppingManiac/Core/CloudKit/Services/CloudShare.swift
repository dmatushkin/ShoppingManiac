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

	@Autowired
    private var cloudKitUtils: CloudKitUtilsProtocol

    func setupUserPermissions() {
        CKContainer.default().accountStatus { (status, error) in
            if let error = error {
                SwiftyBeaver.debug("CloudKit account error \(error)")
            } else if status == .available {
                CKContainer.default().status(forApplicationPermission: .userDiscoverability, completionHandler: {[weak self] (status, error) in
                    if let error = error {
                        SwiftyBeaver.debug("CloudKit discoverability status error \(error)")
                    } else if status == .granted {
                        AppDelegate.discoverabilityStatus = true
                        self?.createZone()
                        SwiftyBeaver.debug("CloudKit discoverability status ok")
                    } else if status == .initialState {
                        CKContainer.default().requestApplicationPermission(.userDiscoverability, completionHandler: {[weak self] (status, error) in
                            if let error = error {
                                SwiftyBeaver.debug("CloudKit discoverability status error \(error)")
                            } else if status == .granted {
                                AppDelegate.discoverabilityStatus = true
                                self?.createZone()
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

    func shareList(list: ShoppingList) -> Observable<CKShare> {
        return getListWrapper(list: list).flatMap(createShare)
    }

    func updateList(list: ShoppingList) -> Observable<Void> {
        return getListWrapper(list: list).flatMap(updateRecord)
    }
    
    private func createShare(wrapper: ShoppingListItemsWrapper) -> Observable<CKShare> {
        return Observable<CKShare>.create {[weak self] observer in
            guard let self = self else { return Disposables.create() }
            let share = CKShare(rootRecord: wrapper.record)
            share[CKShare.SystemFieldKey.title] = "Shopping list" as CKRecordValue
            share[CKShare.SystemFieldKey.shareType] = "org.md.ShoppingManiac" as CKRecordValue
            share.publicPermission = .readWrite
            
            let recordsToUpdate = [wrapper.record, share]
            
			let disposable = self.cloudKitUtils.updateRecords(records: recordsToUpdate, localDb: true).map({(wrapper.items, true)}).flatMap(self.updateRecords).subscribe(onError: {error in
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
    
    private func createZone() {
        let recordZone = CKRecordZone(zoneName: CloudKitUtils.zoneName)
        CKContainer.default().privateCloudDatabase.save(recordZone) { (_, error) in
            if let error = error {
                SwiftyBeaver.debug("Error saving zone \(error.localizedDescription)")
            }
        }
    }

	private func updateListWrapper(tuple: (record: CKRecord, list: ShoppingList)) -> Observable<ShoppingListItemsWrapper> {
        return getItemsRecords(list: tuple.list).toArray().asObservable().map({items in
            for item in items {
                item.setParent(tuple.record)
            }
            tuple.record["name"] = (tuple.list.name ?? "") as CKRecordValue
            tuple.record["date"] = Date(timeIntervalSinceReferenceDate: tuple.list.date) as CKRecordValue
            tuple.record["isRemoved"] = tuple.list.isRemoved as CKRecordValue
            tuple.record["items"] = items.map({ CKRecord.Reference(record: $0, action: .deleteSelf) }) as CKRecordValue
            return ShoppingListItemsWrapper(localDb: !tuple.list.isRemote, shoppingList: tuple.list, record: tuple.record, items: items, ownerName: tuple.list.ownerName)
        })
    }

    private func updateItemRecord(record: CKRecord, item: ShoppingListItem) -> CKRecord {
        record["comment"] = (item.comment ?? "") as CKRecordValue
        record["goodName"] = (item.good?.name ?? "") as CKRecordValue
        record["isWeight"] = item.isWeight as CKRecordValue
        record["price"] = item.price as CKRecordValue
        record["purchased"] = item.purchased as CKRecordValue
        record["quantity"] = item.quantity as CKRecordValue
        record["storeName"] = (item.store?.name ?? "") as CKRecordValue
        record["isRemoved"] = item.isRemoved as CKRecordValue
        record["isCrossListItem"] = item.isCrossListItem as CKRecordValue
        return record
    }
    
    private func zone(ownerName: String?) -> CKRecordZone {
        if let ownerName = ownerName {
            return CKRecordZone(zoneID: CKRecordZone.ID(zoneName: CloudKitUtils.zoneName, ownerName: ownerName))
        } else {
            return CKRecordZone(zoneName: CloudKitUtils.zoneName)
        }
    }

    private func getListWrapper(list: ShoppingList) -> Observable<ShoppingListItemsWrapper> {
        let recordZone = zone(ownerName: list.ownerName).zoneID
        if let recordName = list.recordid {
            let recordId = CKRecord.ID(recordName: recordName, zoneID: recordZone)
            return cloudKitUtils.fetchRecords(recordIds: [recordId], localDb: !list.isRemote).map({($0, list)}).flatMap(self.updateListWrapper)
        } else {
            let recordName = CKRecord.ID().recordName
            let recordId = CKRecord.ID(recordName: recordName, zoneID: recordZone)
            let record = CKRecord(recordType: CloudKitUtils.listRecordType, recordID: recordId)
            list.setRecordId(recordId: recordName)
            return updateListWrapper(tuple: (record, list))
        }
    }
    
    private func getItemsRecords(list: ShoppingList) -> Observable<CKRecord> {
        return Observable<CKRecord>.create {[weak self] observer in
            guard let self = self else { fatalError() }
            let items = list.listItems
            let locals = items.filter({$0.recordid == nil})
            let shares = items.filter({$0.recordid != nil}).reduce(into: [String: ShoppingListItem](), {result, item in
                if let recordId = item.recordid {
                    result[recordId] = item
                }
            })
            let listIsRemote = list.isRemote
            let recordZone = self.zone(ownerName: list.ownerName).zoneID
            for local in locals {
                let recordName = CKRecord.ID().recordName
                let recordId = CKRecord.ID(recordName: recordName, zoneID: recordZone)
                let record = CKRecord(recordType: CloudKitUtils.itemRecordType, recordID: recordId)
                local.setRecordId(recordId: recordName)
                observer.onNext(self.updateItemRecord(record: record, item: local))
            }
            if shares.count > 0 {
                let disposable = self.cloudKitUtils.fetchRecords(recordIds: shares.keys.map({CKRecord.ID(recordName: $0, zoneID: recordZone)}), localDb: !listIsRemote)
                    .subscribe(onNext: {record in
                    if let item = shares[record.recordID.recordName] {
                        observer.onNext(self.updateItemRecord(record: record, item: item))
                    }
                }, onError: {error in
                    observer.onError(error)
                }, onCompleted: {
                    observer.onCompleted()
                })
                return Disposables.create {
                    disposable.dispose()
                }
            } else {
                observer.onCompleted()
                return Disposables.create()
            }            
        }
    }
    
    private func updateRecord(wrapper: ShoppingListItemsWrapper) -> Observable<Void> {
        if let shareRef = wrapper.record.share {
			return cloudKitUtils.fetchRecords(recordIds: [shareRef.recordID], localDb: wrapper.localDb)
				.map({([wrapper.record, $0], wrapper.localDb)}).flatMap(updateRecords)
				.map({(wrapper.items, wrapper.localDb)}).flatMap(updateRecords)
        } else {
            return cloudKitUtils.updateRecords(records: [wrapper.record], localDb: wrapper.localDb)
				.map({(wrapper.items, wrapper.localDb)}).flatMap(updateRecords)
        }
    }
	
	private func updateRecords(tuple: (records: [CKRecord], localDb: Bool)) -> Observable<Void> {
		return self.cloudKitUtils.updateRecords(records: tuple.records, localDb: tuple.localDb)
	}
}
