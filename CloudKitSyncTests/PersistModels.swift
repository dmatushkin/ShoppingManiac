//
//  PersistModels.swift
//  CloudKitSyncTests
//
//  Created by Dmitry Matyushkin on 8/26/20.
//  Copyright © 2020 Dmitry Matyushkin. All rights reserved.
//

import Foundation
import CloudKitSync
import Combine
import CloudKit

class TestShareMetadata: CKShare.Metadata {

    override var rootRecordID: CKRecord.ID {
        return CKRecord.ID(recordName: "testShareRecord", zoneID: CKRecordZone.ID(zoneName: "testRecordZone", ownerName: "testRecordOwner"))
    }
}

class SharedRecord: CKRecord {

    override var share: CKRecord.Reference? {
        let recordId = CKRecord.ID(recordName: "shareTestRecord")
        let record = CKRecord(recordType: "cloudkit.share", recordID: recordId)
        return CKRecord.Reference(record: record, action: .none)
    }
}

class TestShoppingList: CloudKitSyncItemProtocol {

	var items = [TestShoppingItem]()
	var name: String?
	var ownerName: String?
	var date: TimeInterval = 0

	func appendItem(item: TestShoppingItem) {
		if !items.contains(item) {
			items.append(item)
		}
	}

	static var zoneName: String {
		return "testZone"
	}

	static var recordType: String {
		return "testListRecord"
	}

	static var hasDependentItems: Bool {
		return true
	}

	static var dependentItemsRecordAttribute: String {
		return "items"
	}

	static var dependentItemsType: CloudKitSyncItemProtocol.Type {
		return TestShoppingItem.self
	}

	var isRemote: Bool = false

	func dependentItems() -> [CloudKitSyncItemProtocol] {
		return items
	}

	var recordId: String?

	func setRecordId(_ recordId: String) -> AnyPublisher<CloudKitSyncItemProtocol, Error> {
		self.recordId = recordId
		return Future {[unowned self] promise in
			return promise(.success(self))
		}.eraseToAnyPublisher()
	}

	func populate(record: CKRecord) -> AnyPublisher<CKRecord, Error> {
		record["name"] = name
		record["date"] = Date(timeIntervalSinceReferenceDate: date)
		return Future { promise in
			return promise(.success(record))
		}.eraseToAnyPublisher()
	}

	static func store(record: CKRecord, isRemote: Bool) -> AnyPublisher<CloudKitSyncItemProtocol, Error> {
		return Future { promise in
			let list = TestShoppingList()
			list.recordId = record.recordID.recordName
			list.ownerName = record.recordID.zoneID.ownerName
			list.isRemote = isRemote
			list.name = record["name"] as? String
			let date = record["date"] as? Date ?? Date()
			list.date = date.timeIntervalSinceReferenceDate
			return promise(.success(list))
		}.eraseToAnyPublisher()
	}

	func setParent(item: CloudKitSyncItemProtocol) -> AnyPublisher<CloudKitSyncItemProtocol, Error> {
		fatalError()
	}
}

class TestShoppingItem: CloudKitSyncItemProtocol, Equatable {

	static func == (lhs: TestShoppingItem, rhs: TestShoppingItem) -> Bool {
		return lhs.recordId == rhs.recordId && lhs.ownerName == rhs.ownerName && lhs.goodName == rhs.goodName && lhs.storeName == rhs.storeName && lhs.isRemote == rhs.isRemote
	}

	var goodName: String?
	var storeName: String?
	var ownerName: String?

	static var zoneName: String {
		return "testZone"
	}

	static var recordType: String {
		return "testItemRecord"
	}

	static var hasDependentItems: Bool {
		return false
	}

	static var dependentItemsRecordAttribute: String {
		   return "items"
	}

	static var dependentItemsType: CloudKitSyncItemProtocol.Type {
		   return TestShoppingItem.self
	}

	var isRemote: Bool = false

	func dependentItems() -> [CloudKitSyncItemProtocol] {
		return []
	}

	var recordId: String?

	func setRecordId(_ recordId: String) -> AnyPublisher<CloudKitSyncItemProtocol, Error> {
		self.recordId = recordId
		return Future {[unowned self] promise in
			return promise(.success(self))
		}.eraseToAnyPublisher()
	}

	func populate(record: CKRecord) -> AnyPublisher<CKRecord, Error> {
		record["goodName"] = goodName
		record["storeName"] = storeName
		return Future { promise in
			return promise(.success(record))
		}.eraseToAnyPublisher()
	}

	static func store(record: CKRecord, isRemote: Bool) -> AnyPublisher<CloudKitSyncItemProtocol, Error> {
		return Future { promise in
			let item = TestShoppingItem()
			item.recordId = record.recordID.recordName
			item.ownerName = record.recordID.zoneID.ownerName
			item.isRemote = isRemote
			item.goodName = record["goodName"] as? String
			item.storeName = record["storeName"] as? String
			return promise(.success(item))
		}.eraseToAnyPublisher()
	}

	func setParent(item: CloudKitSyncItemProtocol) -> AnyPublisher<CloudKitSyncItemProtocol, Error> {
		(item as? TestShoppingList)?.appendItem(item: self)
		return Future {[unowned self] promise in
			return promise(.success(self))
		}.eraseToAnyPublisher()
	}
}
