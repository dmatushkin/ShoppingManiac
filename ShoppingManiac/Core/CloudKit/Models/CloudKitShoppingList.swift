//
//  CloudKitShoppingList.swift
//  ShoppingManiac
//
//  Created by Dmitry Matyushkin on 9/2/20.
//  Copyright © 2020 Dmitry Matyushkin. All rights reserved.
//

import Foundation
import CloudKitSync
import CloudKit
import CoreData
import Combine

class CloudKitShoppingList: CloudKitSyncItemProtocol {

	// MARK: - Core Data id
	var objectID: NSManagedObjectID?

	// MARK: - Data fields
	var name: String?
	var date: Date = Date()
	var items: [CloudKitShoppingItem] = []
	var isRemoved: Bool = false

	// MARK: - CloudKitSyncItemProtocol

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
		return CloudKitShoppingItem.self
	}

	var isRemote: Bool = false

	func dependentItems() -> [CloudKitSyncItemProtocol] {
		return items
	}

	var recordId: String?

	var ownerName: String?

	func populate(record: CKRecord) {
		record["name"] = (name ?? "") as CKRecordValue
		record["date"] = date as CKRecordValue
		record["isRemoved"] = isRemoved as CKRecordValue
	}

	static func store(record: CKRecord, isRemote: Bool, dependentItems: [CloudKitSyncItemProtocol]) -> CloudKitSyncItemProtocol {
		let shoppingList = CloudKitShoppingList()
		shoppingList.recordId = record.recordID.recordName
		shoppingList.ownerName = record.recordID.zoneID.ownerName
		shoppingList.name = record["name"] as? String
		shoppingList.isRemote = isRemote
		shoppingList.isRemoved = record["isRemoved"] as? Bool ?? false
		shoppingList.date = record["date"] as? Date ?? Date()
		shoppingList.items = dependentItems as? [CloudKitShoppingItem] ?? []
		return shoppingList
	}

	func persistModelChanges() -> AnyPublisher<Void, Error> {
		return ShoppingList.storeModel(model: self).map({ _ in }).eraseToAnyPublisher()
	}
}


extension Array where Element == CloudKitShoppingList {

	func persistModelChanges() -> AnyPublisher<Void, Error> {
		return ShoppingList.storeModels(models: self).map({_ in }).eraseToAnyPublisher()
	}
}
