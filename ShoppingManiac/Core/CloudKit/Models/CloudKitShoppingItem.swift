//
//  CloudKitShoppingItem.swift
//  ShoppingManiac
//
//  Created by Dmitry Matyushkin on 9/2/20.
//  Copyright © 2020 Dmitry Matyushkin. All rights reserved.
//

import Foundation
import CloudKitSync
import CloudKit
import Combine
import CoreData

class CloudKitShoppingItem: CloudKitSyncItemProtocol {

	// MARK: - Core Data id
	var objectID: NSManagedObjectID?

	// MARK: - Data fields
	var comment: String?
	var goodName: String?
	var storeName: String?
	var isWeight: Bool = false
	var price: Double = 0
	var isPurchased: Bool = false
	var quantity: Int = 0
	var isRemoved: Bool = false
	var isCrossListItem: Bool = false

	// MARK: - CloudKitSyncItemProtocol
	var recordId: String?

	var ownerName: String?

	static var zoneName: String {
		return "ShareZone"
	}

	static var recordType: String {
		return "ShoppingListItem"
	}

	static var hasDependentItems: Bool {
		return false
	}

	static var dependentItemsRecordAttribute: String {
		return ""
	}

	static var dependentItemsType: CloudKitSyncItemProtocol.Type {
		return CloudKitShoppingItem.self
	}

	var isRemote: Bool = false

	func dependentItems() -> [CloudKitSyncItemProtocol] {
		return []
	}

	func populate(record: CKRecord) {
		record["comment"] = (comment ?? "") as CKRecordValue
		record["goodName"] = (goodName ?? "") as CKRecordValue
		record["isWeight"] = isWeight as CKRecordValue
		record["price"] = price as CKRecordValue
		record["purchased"] = isPurchased as CKRecordValue
		record["quantity"] = quantity as CKRecordValue
		record["storeName"] = (storeName ?? "") as CKRecordValue
		record["isRemoved"] = isRemoved as CKRecordValue
		record["isCrossListItem"] = isCrossListItem as CKRecordValue
	}

	static func store(record: CKRecord, isRemote: Bool, dependentItems: [CloudKitSyncItemProtocol]) -> CloudKitSyncItemProtocol {
		let item = CloudKitShoppingItem()
		item.recordId = record.recordID.recordName
		item.ownerName = record.recordID.zoneID.ownerName
		item.comment = record["comment"] as? String
		item.goodName = record["goodName"] as? String
		item.isWeight = record["isWeight"] as? Bool ?? false
		item.price = record["price"] as? Double ?? 0
		item.isPurchased = record["purchased"] as? Bool ?? false
		item.quantity = record["quantity"] as? Int ?? 1
		item.isRemoved = record["isRemoved"] as? Bool ?? false
		item.isCrossListItem = record["isCrossListItem"] as? Bool ?? false
		item.storeName = record["storeName"] as? String
		return item
	}

	func setParent(item: CloudKitSyncItemProtocol) -> AnyPublisher<CloudKitSyncItemProtocol, Error> {
		if let list = item as? CloudKitShoppingList {
			if !list.items.contains(where: {listItem in
				listItem.goodName == self.goodName && listItem.storeName == self.storeName
			}) {
				list.items.append(self)
			}
		}
		let value = self
		return Future {promise in
				return promise(.success(value))
		}.eraseToAnyPublisher()
	}
}
