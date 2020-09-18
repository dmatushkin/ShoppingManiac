//
//  ShoppingListCloudKitSyncExtension.swift
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

extension ShoppingList: CloudKitSyncItemProtocol {

	public static var zoneName: String {
		return "ShareZone"
	}

	public static var recordType: String {
		return "ShoppingList"
	}

	public static var hasDependentItems: Bool {
		return true
	}

	public static var dependentItemsRecordAttribute: String {
		return "items"
	}

	public static var dependentItemsType: CloudKitSyncItemProtocol.Type {
		return ShoppingListItem.self
	}

	public func dependentItems() -> [CloudKitSyncItemProtocol] {
		do {
			if Thread.isMainThread {
				return try CoreStoreDefaults.dataStack.fetchAll(itemsFetchBuilder.orderBy(.descending(\.good?.name)))
			} else {
				let builder = self.itemsFetchBuilder
				return try CoreStoreDefaults.dataStack.perform(synchronous: {transaction in
					return try transaction.fetchAll(builder.orderBy(.descending(\.good?.name)))
				})
			}
		} catch {
			return []
		}
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

	public func setRecordId(_ recordId: String) -> AnyPublisher<CloudKitSyncItemProtocol, Error> {
		return CoreDataOperationPublisher(operation: { transaction in
            if let shoppingList: ShoppingList = transaction.edit(self) {
                shoppingList.recordid = recordId
            }
			return self
		}).eraseToAnyPublisher()
	}

	public func populate(record: CKRecord) -> AnyPublisher<CKRecord, Error> {
		return CoreDataOperationPublisher(operation: {transaction in
			if let list = transaction.fetchExisting(self) {
				record["name"] = (list.name ?? "") as CKRecordValue
				record["date"] = Date(timeIntervalSinceReferenceDate: list.date) as CKRecordValue
				record["isRemoved"] = list.isRemoved as CKRecordValue
			}
			return record
		}).eraseToAnyPublisher()
	}

	public static func store(record: CKRecord, isRemote: Bool) -> AnyPublisher<CloudKitSyncItemProtocol, Error> {
		return CoreDataOperationPublisher(operation: {transaction -> ShoppingList in
			let shoppingList: ShoppingList = try transaction.fetchOne(From<ShoppingList>().where(Where("recordid == %@", record.recordID.recordName))) ?? transaction.create(Into<ShoppingList>())
			shoppingList.recordid = record.recordID.recordName
			shoppingList.ownerName = record.recordID.zoneID.ownerName
			shoppingList.name = record["name"] as? String
			shoppingList.isRemote = isRemote
			shoppingList.isRemoved = record["isRemoved"] as? Bool ?? false
			let date = record["date"] as? Date ?? Date()
			shoppingList.date = date.timeIntervalSinceReferenceDate
			return shoppingList
		}).eraseToAnyPublisher()
	}

	public func setParent(item: CloudKitSyncItemProtocol) -> AnyPublisher<CloudKitSyncItemProtocol, Error> {
		fatalError()
	}
}
