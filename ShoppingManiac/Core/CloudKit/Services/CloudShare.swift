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
                        CloudShare.createZone()
                        SwiftyBeaver.debug("CloudKit discoverability status ok")
                    } else if status == .initialState {
                        CKContainer.default().requestApplicationPermission(.userDiscoverability, completionHandler: { (status, error) in
                            if let error = error {
                                SwiftyBeaver.debug("CloudKit discoverability status error \(error)")
                            } else if status == .granted {
                                AppDelegate.discoverabilityStatus = true
								CloudShare.createZone()
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
		return CoreDataOperationPublisher(operation: { transaction -> ShoppingList in
			guard let shoppingList = transaction.fetchExisting(list) else { fatalError() }
			let items = try transaction.fetchAll(list.itemsFetchBuilder)
			for item in items {
				item.list = shoppingList
			}
			return shoppingList
		}).flatMap({[unowned self] list in
			self.getListWrapper(list: list).flatMap({ wrapper in
				return CloudKitCreateSharePublisher(wrapper: wrapper).eraseToAnyPublisher()
			})
		}).eraseToAnyPublisher()
    }

    func updateList(list: ShoppingList) -> AnyPublisher<Void, Error> {
		return getListWrapper(list: list).flatMap({[unowned self] wrapper in
			return self.updateRecord(wrapper: wrapper)
		}).eraseToAnyPublisher()
    }

    private class func createZone() {
        let recordZone = CKRecordZone(zoneName: CloudKitUtils.zoneName)
        CKContainer.default().privateCloudDatabase.save(recordZone) { (_, error) in
            if let error = error {
                SwiftyBeaver.debug("Error saving zone \(error.localizedDescription)")
            }
        }
    }

	private func updateListWrapper(record: CKRecord, list: ShoppingList) -> AnyPublisher<ShoppingListItemsWrapper, Error> {
		return CloudKitShoppingListItemsPublisher(list: list).collect().map({items in
            for item in items {
                item.setParent(record)
            }
            record["name"] = (list.name ?? "") as CKRecordValue
            record["date"] = Date(timeIntervalSinceReferenceDate: list.date) as CKRecordValue
            record["isRemoved"] = list.isRemoved as CKRecordValue
            record["items"] = items.map({ CKRecord.Reference(record: $0, action: .deleteSelf) }) as CKRecordValue
            return ShoppingListItemsWrapper(localDb: !list.isRemote, shoppingList: list, record: record, items: items, ownerName: list.ownerName)
		}).eraseToAnyPublisher()
    }

    private func getListWrapper(list: ShoppingList) -> AnyPublisher<ShoppingListItemsWrapper, Error> {
		let recordZone = CKRecordZone(ownerName: list.ownerName).zoneID
        if let recordName = list.recordid {
            let recordId = CKRecord.ID(recordName: recordName, zoneID: recordZone)
			return cloudKitUtils.fetchRecords(recordIds: [recordId], localDb: !list.isRemote).flatMap({[unowned self] record in
				return self.updateListWrapper(record: record, list: list)
			}).eraseToAnyPublisher()
        } else {
            let recordName = CKRecord.ID().recordName
            let recordId = CKRecord.ID(recordName: recordName, zoneID: recordZone)
            let record = CKRecord(recordType: CloudKitUtils.listRecordType, recordID: recordId)
			return list.setRecordId(recordId: recordName).flatMap({[unowned self] in
				return self.updateListWrapper(record: record, list: list)
			}).eraseToAnyPublisher()
        }
    }

    private func updateRecord(wrapper: ShoppingListItemsWrapper) -> AnyPublisher<Void, Error> {
        if let shareRef = wrapper.record.share {
			return cloudKitUtils.fetchRecords(recordIds: [shareRef.recordID], localDb: wrapper.localDb)
				.flatMap({[unowned self] record in
					return self.cloudKitUtils.updateRecords(records: [wrapper.record, record], localDb: wrapper.localDb)
				})
				.flatMap({[unowned self] _ in
					return self.cloudKitUtils.updateRecords(records: wrapper.items, localDb: wrapper.localDb)
				}).eraseToAnyPublisher()
        } else {
            return cloudKitUtils.updateRecords(records: [wrapper.record], localDb: wrapper.localDb)
				.flatMap({[unowned self] _ in
					return self.cloudKitUtils.updateRecords(records: wrapper.items, localDb: wrapper.localDb)
				}).eraseToAnyPublisher()
        }
    }
}
