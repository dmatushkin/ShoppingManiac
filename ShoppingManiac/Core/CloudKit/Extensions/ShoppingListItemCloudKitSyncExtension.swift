//
//  ShoppingListItemCloudKitSyncExtension.swift
//  ShoppingManiac
//
//  Created by Dmitry Matyushkin on 8/27/20.
//  Copyright © 2020 Dmitry Matyushkin. All rights reserved.
//

import Foundation
import CoreData
import CloudKitSync
import CloudKit
import CoreStore
import Combine

extension ShoppingListItem: CloudKitSyncItemProtocol {

	public static var zoneName: String {
		return "ShareZone"
	}

	public static var recordType: String {
		return "ShoppingListItem"
	}

	public static var hasDependentItems: Bool {
		return false
	}

	public static var dependentItemsRecordAttribute: String {
		return ""
	}

	public static var dependentItemsType: CloudKitSyncItemProtocol.Type {
		return ShoppingListItem.self
	}

	public var isRemote: Bool {
		if Thread.isMainThread {
			return list?.isRemote ?? false
		} else {
			let value = self
			return (try? CoreStoreDefaults.dataStack.perform(synchronous: {transaction in
				return transaction.fetchExisting(value)?.list?.isRemote
			})) ?? false
		}
	}

	public func dependentItems() -> [CloudKitSyncItemProtocol] {
		return []
	}

	public var recordId: String? {
		if Thread.isMainThread {
			return self.recordid
		} else {
			let value = self
			return try? CoreStoreDefaults.dataStack.perform(synchronous: {transaction in
				return transaction.fetchExisting(value)?.recordid
			})
		}
	}

	public var ownerName: String? {
		if Thread.isMainThread {
			return list?.ownerName
		} else {
			let value = self
			return try? CoreStoreDefaults.dataStack.perform(synchronous: {transaction in
				return transaction.fetchExisting(value)?.list?.ownerName
			})
		}
	}

	public func setRecordId(_ recordId: String) -> AnyPublisher<CloudKitSyncItemProtocol, Error> {
		return CoreDataOperationPublisher(operation: { transaction in
			if let shoppingListItem: ShoppingListItem = transaction.edit(self) {
				shoppingListItem.recordid = recordId
			}
			return self
		}).eraseToAnyPublisher()
	}

	public func populate(record: CKRecord) -> AnyPublisher<CKRecord, Error> {
		return CoreDataOperationPublisher(operation: {transaction in
			if let item = transaction.fetchExisting(self) {
				record["comment"] = (item.comment ?? "") as CKRecordValue
				record["goodName"] = (item.good?.name ?? "") as CKRecordValue
				record["isWeight"] = item.isWeight as CKRecordValue
				record["price"] = item.price as CKRecordValue
				record["purchased"] = item.purchased as CKRecordValue
				record["quantity"] = item.quantity as CKRecordValue
				record["storeName"] = (item.store?.name ?? "") as CKRecordValue
				record["isRemoved"] = item.isRemoved as CKRecordValue
				record["isCrossListItem"] = item.isCrossListItem as CKRecordValue
                record["isImportant"] = item.isImportant as CKRecordValue
			}
			return record
		}).eraseToAnyPublisher()
	}

	public static func store(record: CKRecord, isRemote: Bool) -> AnyPublisher<CloudKitSyncItemProtocol, Error> {
		return CoreDataOperationPublisher(operation: {transaction -> ShoppingListItem in
			let item: ShoppingListItem = try transaction.fetchOne(From<ShoppingListItem>().where(Where("recordid == %@", record.recordID.recordName))) ?? transaction.create(Into<ShoppingListItem>())
			item.recordid = record.recordID.recordName
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
            item.isImportant = record["isImportant"] as? Bool ?? false
			if let storeName = record["storeName"] as? String, storeName.count > 0 {
				let store = try transaction.fetchOne(From<Store>().where(Where("name == %@", storeName))) ?? transaction.create(Into<Store>())
				store.name = storeName
				item.store = store
			} else {
				item.store = nil
			}
			return item
		}).eraseToAnyPublisher()
	}

	public func setParent(item: CloudKitSyncItemProtocol) -> AnyPublisher<CloudKitSyncItemProtocol, Error> {
		return CoreDataOperationPublisher(operation: { transaction in
			if let shoppingListItem: ShoppingListItem = transaction.edit(self), let shoppingList: ShoppingList = transaction.edit(item as? ShoppingList) {
				shoppingListItem.list = shoppingList
			}
			return self
		}).eraseToAnyPublisher()
	}
}
