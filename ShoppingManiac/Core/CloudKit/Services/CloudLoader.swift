//
//  CloudLoader.swift
//  ShoppingManiac
//
//  Created by Dmitry Matyushkin on 21/04/2018.
//  Copyright © 2018 Dmitry Matyushkin. All rights reserved.
//

import Foundation
import CloudKit
import CoreStore
import SwiftyBeaver
import Combine

class CloudLoader {

	@Autowired
    private var cloudKitUtils: CloudKitUtilsProtocol
        
    func loadShare(metadata: CKShare.Metadata) -> AnyPublisher<ShoppingList, Error> {
        return cloudKitUtils.fetchRecords(recordIds: [metadata.rootRecordID], localDb: false)
            .map({RecordWrapper(record: $0, localDb: false, ownerName: metadata.rootRecordID.zoneID.ownerName)})
			.flatMap({[unowned self] wrapper in
				return self.storeListRecord(recordWrapper: wrapper)
			}).flatMap({[unowned self] wrapper in
				return self.fetchListItems(wrapper: wrapper)
			}).flatMap({[unowned self] wrapper in
				return self.storeListItems(wrapper: wrapper)
			}).eraseToAnyPublisher()
    }
    
    private func storeListRecord(recordWrapper: RecordWrapper) -> AnyPublisher<ShoppingListWrapper, Error> {
		return CoreDataOperationPublisher(operation: {transaction -> ShoppingList in
			let shoppingList: ShoppingList = try transaction.fetchOne(From<ShoppingList>().where(Where("recordid == %@", recordWrapper.record.recordID.recordName))) ?? transaction.create(Into<ShoppingList>())
			shoppingList.recordid = recordWrapper.record.recordID.recordName
			shoppingList.ownerName = recordWrapper.ownerName
			shoppingList.name = recordWrapper.record["name"] as? String
			shoppingList.isRemote = !recordWrapper.localDb
			shoppingList.isRemoved = recordWrapper.record["isRemoved"] as? Bool ?? false
			let date = recordWrapper.record["date"] as? Date ?? Date()
			shoppingList.date = date.timeIntervalSinceReferenceDate
			SwiftyBeaver.debug("got a list with name \(shoppingList.name ?? "no name") record \(String(describing: recordWrapper.record))")
			return shoppingList
		}).map({list in
			let items = recordWrapper.record["items"] as? [CKRecord.Reference] ?? []
			return ShoppingListWrapper(localDb: recordWrapper.localDb, record: recordWrapper.record, shoppingList: list, items: items, ownerName: recordWrapper.ownerName)
		}).eraseToAnyPublisher()
    }
    
    private func fetchListItems(wrapper: ShoppingListWrapper) -> AnyPublisher<ShoppingListItemsWrapper, Error> {
        return cloudKitUtils.fetchRecords(recordIds: wrapper.items.map({$0.recordID}), localDb: wrapper.localDb).collect()
			.map({ShoppingListItemsWrapper(localDb: wrapper.localDb, shoppingList: wrapper.shoppingList, record: wrapper.record, items: $0, ownerName: wrapper.ownerName)})
			.eraseToAnyPublisher()
    }

    private func storeListItems(wrapper: ShoppingListItemsWrapper) -> AnyPublisher<ShoppingList, Error> {
		return CoreDataOperationPublisher(operation: {transaction -> ShoppingList in
			for record in wrapper.items {
				let item: ShoppingListItem = try transaction.fetchOne(From<ShoppingListItem>().where(Where("recordid == %@", record.recordID.recordName))) ?? transaction.create(Into<ShoppingListItem>())
				SwiftyBeaver.debug("loading item \(record["goodName"] as? String ?? "no name")")
				item.recordid = record.recordID.recordName
				item.list = transaction.edit(wrapper.shoppingList)
				item.comment = record["comment"] as? String
				if let name = record["goodName"] as? String {
					let good = try transaction.fetchOne(From<Good>().where(Where("name == %@", name))) ?? transaction.create(Into<Good>())
					good.name = name
					item.good = good
				} else {
					item.good = nil
				}
				item.isWeight = record["isWeight"] as? Bool ?? false
				item.price = record["price"] as? Float ?? 0
				item.purchased = record["purchased"] as? Bool ?? false
				item.quantity = record["quantity"] as? Float ?? 1
				item.isRemoved = record["isRemoved"] as? Bool ?? false
				item.isCrossListItem = record["isCrossListItem"] as? Bool ?? false
				if let storeName = record["storeName"] as? String, storeName.count > 0 {
					let store = try transaction.fetchOne(From<Store>().where(Where("name == %@", storeName))) ?? transaction.create(Into<Store>())
					store.name = storeName
					item.store = store
				} else {
					item.store = nil
				}
			}
			return wrapper.shoppingList
		}).eraseToAnyPublisher()
    }

    func fetchChanges(localDb: Bool) -> AnyPublisher<Void, Error> {
        return cloudKitUtils.fetchDatabaseChanges(localDb: localDb)
			.flatMap({[unowned self] wrapper in
				return self.cloudKitUtils.fetchZoneChanges(wrapper: wrapper)
			}).flatMap({[unowned self] records in
				self.processChangesRecords(records: records, localDb: localDb)
			})
			.eraseToAnyPublisher()
    }
    
	private func processChangesRecords(records: [CKRecord], localDb: Bool) -> AnyPublisher<Void, Error> {
		if records.count > 0 {
			let lists = records.filter({$0.recordType == CloudKitUtils.listRecordType}).map({processChangesList(listRecord: $0, allRecords: records, localDb: localDb)})
			let firstList = lists[0].eraseToAnyPublisher()
			return lists.dropFirst().reduce(firstList, {result, item in
				return result.merge(with: item).eraseToAnyPublisher()
			})
        } else {
			return Empty(completeImmediately: true, outputType: Void.self, failureType: Error.self).eraseToAnyPublisher()
        }
    }
    
    private func processChangesList(listRecord: CKRecord, allRecords: [CKRecord], localDb: Bool) -> AnyPublisher<Void, Error> {
        let items = allRecords.filter({$0.recordType == CloudKitUtils.itemRecordType && $0.parent?.recordID.recordName == listRecord.recordID.recordName})
        let ownerName = listRecord.recordID.zoneID.ownerName
        let wrapper = RecordWrapper(record: listRecord, localDb: localDb, ownerName: ownerName)
        return storeListRecord(recordWrapper: wrapper)
            .map({ShoppingListItemsWrapper(localDb: localDb, shoppingList: $0.shoppingList, record: listRecord, items: items, ownerName: ownerName)})
			.flatMap({[unowned self] wrapper in
				self.storeListItems(wrapper: wrapper)
			}).last().map({_ in ()}).eraseToAnyPublisher()
    }
}
