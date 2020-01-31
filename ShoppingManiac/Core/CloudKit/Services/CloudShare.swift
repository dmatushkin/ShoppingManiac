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
    
    private let cloudKitUtils: CloudKitUtilsProtocol
    
    init(cloudKitUtils: CloudKitUtilsProtocol) {
        self.cloudKitUtils = cloudKitUtils
    }

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
            
            let disposable = self.cloudKitUtils.updateRecords(records: recordsToUpdate, localDb: true).flatMap({[weak self] _ -> Observable<Void> in
                guard let self = self else { fatalError() }
                return self.cloudKitUtils.updateRecords(records: wrapper.items, localDb: true)
            }).subscribe(onError: {error in
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

    private func updateListWrapper(tuple: (CKRecord, ShoppingList)) -> Observable<ShoppingListItemsWrapper> {
        return Observable.from(tuple.1.listItems.map({getItemRecord(item: $0)})).merge().toArray().asObservable().map({items in
            for item in items {
                item.setParent(tuple.0)
            }
            tuple.0["name"] = (tuple.1.name ?? "") as CKRecordValue
            tuple.0["date"] = Date(timeIntervalSinceReferenceDate: tuple.1.date) as CKRecordValue
            tuple.0["isRemoved"] = tuple.1.isRemoved as CKRecordValue
            tuple.0["items"] = items.map({ CKRecord.Reference(record: $0, action: .deleteSelf) }) as CKRecordValue
            return ShoppingListItemsWrapper(localDb: !tuple.1.isRemote, shoppingList: tuple.1, record: tuple.0, items: items, ownerName: tuple.1.ownerName)
        })
    }

    private func updateItemRecord(tuple: (CKRecord, ShoppingListItem)) -> CKRecord {
        tuple.0["comment"] = (tuple.1.comment ?? "") as CKRecordValue
        tuple.0["goodName"] = (tuple.1.good?.name ?? "") as CKRecordValue
        tuple.0["isWeight"] = tuple.1.isWeight as CKRecordValue
        tuple.0["price"] = tuple.1.price as CKRecordValue
        tuple.0["purchased"] = tuple.1.purchased as CKRecordValue
        tuple.0["quantity"] = tuple.1.quantity as CKRecordValue
        tuple.0["storeName"] = (tuple.1.store?.name ?? "") as CKRecordValue
        tuple.0["isRemoved"] = tuple.1.isRemoved as CKRecordValue
        tuple.0["isCrossListItem"] = tuple.1.isCrossListItem as CKRecordValue
        return tuple.0
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

    private func getItemRecord(item: ShoppingListItem) -> Observable<CKRecord> {
        let recordZone = zone(ownerName: item.list?.ownerName).zoneID
        if let recordName = item.recordid {
            let recordId = CKRecord.ID(recordName: recordName, zoneID: recordZone)
            return cloudKitUtils.fetchRecords(recordIds: [recordId], localDb: !(item.list?.isRemote ?? false)).map({($0, item)}).map(self.updateItemRecord)
        } else {
            let recordName = CKRecord.ID().recordName
            let recordId = CKRecord.ID(recordName: recordName, zoneID: recordZone)
            let record = CKRecord(recordType: CloudKitUtils.itemRecordType, recordID: recordId)
            item.setRecordId(recordId: recordName)
            return Observable.just(updateItemRecord(tuple: (record, item)))
        }
    }
    
    private func updateRecord(wrapper: ShoppingListItemsWrapper) -> Observable<Void> {
        if let shareRef = wrapper.record.share {
            return cloudKitUtils.fetchRecords(recordIds: [shareRef.recordID], localDb: wrapper.localDb).flatMap({[weak self] shareRecord -> Observable<Void> in
                guard let self = self else { fatalError() }
                return self.cloudKitUtils.updateRecords(records: [wrapper.record, shareRecord], localDb: wrapper.localDb).flatMap({[weak self] _ -> Observable<Void> in
                    guard let self = self else { fatalError() }
                    return self.cloudKitUtils.updateRecords(records: wrapper.items, localDb: wrapper.localDb)
                })
            })
        } else {
            return cloudKitUtils.updateRecords(records: [wrapper.record], localDb: wrapper.localDb).flatMap({[weak self] _ -> Observable<Void> in
                guard let self = self else { fatalError() }
                return self.cloudKitUtils.updateRecords(records: wrapper.items, localDb: wrapper.localDb)
            })
        }
    }
}
