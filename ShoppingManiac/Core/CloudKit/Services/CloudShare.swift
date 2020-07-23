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
import Combine

extension CKRecordZone {

	convenience init(ownerName: String?) {
		if let ownerName = ownerName {
			self.init(zoneID: CKRecordZone.ID(zoneName: CloudKitUtils.zoneName, ownerName: ownerName))
        } else {
			self.init(zoneName: CloudKitUtils.zoneName)
        }
	}
}

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

    func shareList(list: ShoppingList) -> AnyPublisher<CKShare, Error> {
		return getListWrapper(list: list).flatMap(createShare).eraseToAnyPublisher()
    }

    func updateList(list: ShoppingList) -> AnyPublisher<Void, Error> {
		return getListWrapper(list: list).flatMap(updateRecord).eraseToAnyPublisher()
    }
    
    private func createShare(wrapper: ShoppingListItemsWrapper) -> AnyPublisher<CKShare, Error> {
		return CloudKitCreateSharePublisher(wrapper: wrapper).eraseToAnyPublisher()
    }
    
    private func createZone() {
        let recordZone = CKRecordZone(zoneName: CloudKitUtils.zoneName)
        CKContainer.default().privateCloudDatabase.save(recordZone) { (_, error) in
            if let error = error {
                SwiftyBeaver.debug("Error saving zone \(error.localizedDescription)")
            }
        }
    }

	private func updateListWrapper(tuple: (record: CKRecord, list: ShoppingList)) -> AnyPublisher<ShoppingListItemsWrapper, Error> {
		return CloudKitShoppingListItemsPublisher(list: tuple.list).collect().map({items in
            for item in items {
                item.setParent(tuple.record)
            }
            tuple.record["name"] = (tuple.list.name ?? "") as CKRecordValue
            tuple.record["date"] = Date(timeIntervalSinceReferenceDate: tuple.list.date) as CKRecordValue
            tuple.record["isRemoved"] = tuple.list.isRemoved as CKRecordValue
            tuple.record["items"] = items.map({ CKRecord.Reference(record: $0, action: .deleteSelf) }) as CKRecordValue
            return ShoppingListItemsWrapper(localDb: !tuple.list.isRemote, shoppingList: tuple.list, record: tuple.record, items: items, ownerName: tuple.list.ownerName)
		}).eraseToAnyPublisher()
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

    private func getListWrapper(list: ShoppingList) -> AnyPublisher<ShoppingListItemsWrapper, Error> {
		let recordZone = CKRecordZone(ownerName: list.ownerName).zoneID
        if let recordName = list.recordid {
            let recordId = CKRecord.ID(recordName: recordName, zoneID: recordZone)
			return cloudKitUtils.fetchRecords(recordIds: [recordId], localDb: !list.isRemote).map({($0, list)}).flatMap(self.updateListWrapper).eraseToAnyPublisher()
        } else {
            let recordName = CKRecord.ID().recordName
            let recordId = CKRecord.ID(recordName: recordName, zoneID: recordZone)
            let record = CKRecord(recordType: CloudKitUtils.listRecordType, recordID: recordId)
            list.setRecordId(recordId: recordName)
            return updateListWrapper(tuple: (record, list))
        }
    }

    private func updateRecord(wrapper: ShoppingListItemsWrapper) -> AnyPublisher<Void, Error> {
        if let shareRef = wrapper.record.share {
			return cloudKitUtils.fetchRecords(recordIds: [shareRef.recordID], localDb: wrapper.localDb)
				.map({([wrapper.record, $0], wrapper.localDb)}).flatMap(updateRecords)
				.map({(wrapper.items, wrapper.localDb)}).flatMap(updateRecords).eraseToAnyPublisher()
        } else {
            return cloudKitUtils.updateRecords(records: [wrapper.record], localDb: wrapper.localDb)
				.map({(wrapper.items, wrapper.localDb)}).flatMap(updateRecords).eraseToAnyPublisher()
        }
    }
	
	private func updateRecords(tuple: (records: [CKRecord], localDb: Bool)) -> AnyPublisher<Void, Error> {
		return self.cloudKitUtils.updateRecords(records: tuple.records, localDb: tuple.localDb)
	}
}
