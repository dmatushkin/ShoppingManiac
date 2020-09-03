//
//  CloudKitSyncShareTests.swift
//  CloudKitSyncTests
//
//  Created by Dmitry Matyushkin on 8/27/20.
//  Copyright © 2020 Dmitry Matyushkin. All rights reserved.
//

import XCTest
import CoreStore
import CloudKit
import Combine
import DependencyInjection
import CommonError
@testable import CloudKitSync

//swiftlint:disable type_body_length function_body_length file_length

class CloudKitSyncShareTests: XCTestCase {

	private let utilsStub = CloudKitSyncUtilsStub()
	private var cloudShare: CloudKitSyncShare!

	override func setUp() {
		DIProvider.shared
			.register(forType: CloudKitSyncUtilsProtocol.self, lambda: { self.utilsStub })
		self.cloudShare = CloudKitSyncShare()
		self.utilsStub.cleanup()
	}

	override func tearDown() {
		DIProvider.shared.clear()
		self.cloudShare = nil
		self.utilsStub.cleanup()
	}

	func testShareLocalShoppingList() throws {

		let testShoppingList = TestShoppingList()
		let testShoppingItem1 = TestShoppingItem()
		let testShoppingItem2 = TestShoppingItem()
		testShoppingList.name = "test name"
		testShoppingList.date = 602175855.0
		testShoppingList.items = [testShoppingItem1, testShoppingItem2]
		testShoppingItem1.goodName = "good1"
		testShoppingItem1.storeName = "store1"
		testShoppingItem2.goodName = "good2"
		testShoppingItem2.storeName = "store2"

		var recordsUpdateIteration: Int = 0
		self.utilsStub.onUpdateRecords = { (records, localDb) -> Error? in
			recordsUpdateIteration += 1
			if recordsUpdateIteration == 1 {
				XCTAssertEqual(records.count, 2)
				XCTAssertTrue(localDb)
				let listRecord = records[0]
				let items = listRecord[TestShoppingList.dependentItemsRecordAttribute] as? [CKRecord.Reference] ?? []
				XCTAssertEqual(listRecord.recordType, "testListRecord")
				XCTAssertNotEqual(listRecord.share, nil)
				XCTAssertEqual(listRecord["name"] as? String, "test name")
				XCTAssertEqual((listRecord["date"] as? Date)?.timeIntervalSinceReferenceDate, 602175855.0)
				XCTAssertEqual(records[1].recordType, "cloudkit.share")
				XCTAssertEqual(items.count, 2)
				XCTAssertEqual(items[0].recordID.recordName, testShoppingItem1.recordId)
				XCTAssertEqual(items[1].recordID.recordName, testShoppingItem2.recordId)
				return nil
			} else if recordsUpdateIteration == 2 {
				XCTAssertEqual(records.count, 2)
				XCTAssertTrue(localDb)
				XCTAssertEqual(records[0].recordType, "testItemRecord")
				XCTAssertEqual(records[1].recordType, "testItemRecord")
				XCTAssertEqual(records[0].parent?.recordID.recordName, testShoppingList.recordId)
				XCTAssertEqual(records[1].parent?.recordID.recordName, testShoppingList.recordId)
				if records[0]["goodName"] as? String == "good1" {
					XCTAssertEqual(records[0]["goodName"] as? String, "good1")
					XCTAssertEqual(records[0]["storeName"] as? String, "store1")
					XCTAssertEqual(records[1]["goodName"] as? String, "good2")
					XCTAssertEqual(records[1]["storeName"] as? String, "store2")
				} else {
					XCTAssertEqual(records[0]["goodName"] as? String, "good2")
					XCTAssertEqual(records[0]["storeName"] as? String, "store2")
					XCTAssertEqual(records[1]["goodName"] as? String, "good1")
					XCTAssertEqual(records[1]["storeName"] as? String, "store1")
				}
				return nil
			} else {
				XCTAssertTrue(false)
				return nil
			}
		}
		let share = try self.cloudShare.shareItem(item: testShoppingList, shareTitle: "Shopping List", shareType: "org.md.ShoppingManiac").getValue(test: self, timeout: 10)
		XCTAssertEqual(share[CKShare.SystemFieldKey.title] as? String, "Shopping List")
		XCTAssertEqual(share[CKShare.SystemFieldKey.shareType] as? String, "org.md.ShoppingManiac")
		XCTAssertEqual(recordsUpdateIteration, 2)
		XCTAssertNotNil(testShoppingList.recordId)
		XCTAssertNotNil(testShoppingItem1.recordId)
		XCTAssertNotNil(testShoppingItem2.recordId)
	}

	func testShareLocalShoppingListFailOnUpdateList() throws {

		let testShoppingList = TestShoppingList()
		let testShoppingItem1 = TestShoppingItem()
		let testShoppingItem2 = TestShoppingItem()
		testShoppingList.name = "test name"
		testShoppingList.date = 602175855.0
		testShoppingList.items = [testShoppingItem1, testShoppingItem2]
		testShoppingItem1.goodName = "good1"
		testShoppingItem1.storeName = "store1"
		testShoppingItem2.goodName = "good2"
		testShoppingItem2.storeName = "store2"

		var recordsUpdateIteration: Int = 0
		self.utilsStub.onUpdateRecords = { (records, localDb) -> Error? in
			recordsUpdateIteration += 1
			if recordsUpdateIteration == 1 {
				XCTAssertEqual(records.count, 2)
				XCTAssertTrue(localDb)
				let listRecord = records[0]
				let items = listRecord[TestShoppingList.dependentItemsRecordAttribute] as? [CKRecord.Reference] ?? []
				XCTAssertEqual(listRecord.recordType, "testListRecord")
				XCTAssertNotEqual(listRecord.share, nil)
				XCTAssertEqual(listRecord["name"] as? String, "test name")
				XCTAssertEqual((listRecord["date"] as? Date)?.timeIntervalSinceReferenceDate, 602175855.0)
				XCTAssertEqual(records[1].recordType, "cloudkit.share")
				XCTAssertEqual(items.count, 2)
				XCTAssertEqual(items[0].recordID.recordName, testShoppingItem1.recordId)
				XCTAssertEqual(items[1].recordID.recordName, testShoppingItem2.recordId)
				return CommonError(description: "test error")
			} else if recordsUpdateIteration == 2 {
				return nil
			} else {
				XCTAssertTrue(false)
				return nil
			}
		}
		do {
			_ = try self.cloudShare.shareItem(item: testShoppingList, shareTitle: "Shopping List", shareType: "org.md.ShoppingManiac").getValue(test: self, timeout: 10)
			XCTAssertTrue(false, "error should happened")
		} catch {
			XCTAssertEqual(error.localizedDescription, "test error")
		}
		XCTAssertEqual(recordsUpdateIteration, 1)
	}

	func testShareLocalShoppingListFailOnUpdateItems() throws {

		let testShoppingList = TestShoppingList()
		let testShoppingItem1 = TestShoppingItem()
		let testShoppingItem2 = TestShoppingItem()
		testShoppingList.name = "test name"
		testShoppingList.date = 602175855.0
		testShoppingList.items = [testShoppingItem1, testShoppingItem2]
		testShoppingItem1.goodName = "good1"
		testShoppingItem1.storeName = "store1"
		testShoppingItem2.goodName = "good2"
		testShoppingItem2.storeName = "store2"

		var recordsUpdateIteration: Int = 0
		self.utilsStub.onUpdateRecords = { (records, localDb) -> Error? in
			recordsUpdateIteration += 1
			if recordsUpdateIteration == 1 {
				XCTAssertEqual(records.count, 2)
				XCTAssertTrue(localDb)
				let listRecord = records[0]
				let items = listRecord[TestShoppingList.dependentItemsRecordAttribute] as? [CKRecord.Reference] ?? []
				XCTAssertEqual(listRecord.recordType, "testListRecord")
				XCTAssertNotEqual(listRecord.share, nil)
				XCTAssertEqual(listRecord["name"] as? String, "test name")
				XCTAssertEqual((listRecord["date"] as? Date)?.timeIntervalSinceReferenceDate, 602175855.0)
				XCTAssertEqual(records[1].recordType, "cloudkit.share")
				XCTAssertEqual(items.count, 2)
				XCTAssertEqual(items[0].recordID.recordName, testShoppingItem1.recordId)
				XCTAssertEqual(items[1].recordID.recordName, testShoppingItem2.recordId)
				return nil
			} else if recordsUpdateIteration == 2 {
				XCTAssertEqual(records.count, 2)
				XCTAssertTrue(localDb)
				XCTAssertEqual(records[0].recordType, "testItemRecord")
				XCTAssertEqual(records[1].recordType, "testItemRecord")
				XCTAssertEqual(records[0].parent?.recordID.recordName, testShoppingList.recordId)
				XCTAssertEqual(records[1].parent?.recordID.recordName, testShoppingList.recordId)
				if records[0]["goodName"] as? String == "good1" {
					XCTAssertEqual(records[0]["goodName"] as? String, "good1")
					XCTAssertEqual(records[0]["storeName"] as? String, "store1")
					XCTAssertEqual(records[1]["goodName"] as? String, "good2")
					XCTAssertEqual(records[1]["storeName"] as? String, "store2")
				} else {
					XCTAssertEqual(records[0]["goodName"] as? String, "good2")
					XCTAssertEqual(records[0]["storeName"] as? String, "store2")
					XCTAssertEqual(records[1]["goodName"] as? String, "good1")
					XCTAssertEqual(records[1]["storeName"] as? String, "store1")
				}
				return CommonError(description: "test error")
			} else {
				XCTAssertTrue(false)
				return nil
			}
		}
		do {
			_ = try self.cloudShare.shareItem(item: testShoppingList, shareTitle: "Shopping List", shareType: "org.md.ShoppingManiac").getValue(test: self, timeout: 10)
			XCTAssertTrue(false, "error should happened")
		} catch {
			XCTAssertEqual(error.localizedDescription, "test error")
		}
		XCTAssertEqual(recordsUpdateIteration, 2)
	}

	func testUpdateLocalShoppingList() throws {
		let testShoppingList = TestShoppingList()
		let testShoppingItem1 = TestShoppingItem()
		let testShoppingItem2 = TestShoppingItem()
		testShoppingList.name = "test name"
		testShoppingList.date = 602175855.0
		testShoppingList.items = [testShoppingItem1, testShoppingItem2]
		testShoppingItem1.goodName = "good1"
		testShoppingItem1.storeName = "store1"
		testShoppingItem2.goodName = "good2"
		testShoppingItem2.storeName = "store2"

		var recordsUpdateIteration: Int = 0
		self.utilsStub.onUpdateRecords = { (records, localDb) -> Error? in
			recordsUpdateIteration += 1
			if recordsUpdateIteration == 1 {
				XCTAssertEqual(records.count, 1)
				XCTAssertTrue(localDb)
				let listRecord = records[0]
				let items = listRecord[TestShoppingList.dependentItemsRecordAttribute] as? [CKRecord.Reference] ?? []
				XCTAssertEqual(listRecord.recordType, "testListRecord")
				XCTAssertEqual(listRecord.share, nil)
				XCTAssertEqual(listRecord["name"] as? String, "test name")
				XCTAssertEqual((listRecord["date"] as? Date)?.timeIntervalSinceReferenceDate, 602175855.0)
				XCTAssertEqual(items.count, 2)
				XCTAssertEqual(items[0].recordID.recordName, testShoppingItem1.recordId)
				XCTAssertEqual(items[1].recordID.recordName, testShoppingItem2.recordId)
				return nil
			} else if recordsUpdateIteration == 2 {
				XCTAssertEqual(records.count, 2)
				XCTAssertTrue(localDb)
				XCTAssertEqual(records[0].recordType, "testItemRecord")
				XCTAssertEqual(records[1].recordType, "testItemRecord")
				XCTAssertEqual(records[0].parent?.recordID.recordName, testShoppingList.recordId)
				XCTAssertEqual(records[1].parent?.recordID.recordName, testShoppingList.recordId)
				if records[0]["goodName"] as? String == "good1" {
					XCTAssertEqual(records[0]["goodName"] as? String, "good1")
					XCTAssertEqual(records[0]["storeName"] as? String, "store1")
					XCTAssertEqual(records[1]["goodName"] as? String, "good2")
					XCTAssertEqual(records[1]["storeName"] as? String, "store2")
				} else {
					XCTAssertEqual(records[0]["goodName"] as? String, "good2")
					XCTAssertEqual(records[0]["storeName"] as? String, "store2")
					XCTAssertEqual(records[1]["goodName"] as? String, "good1")
					XCTAssertEqual(records[1]["storeName"] as? String, "store1")
				}
				return nil
			} else {
				XCTAssertTrue(false)
				return nil
			}
		}
		_ = try self.cloudShare.updateItem(item: testShoppingList).getValue(test: self, timeout: 10)
		XCTAssertEqual(recordsUpdateIteration, 2)
		XCTAssertNotNil(testShoppingList.recordId)
		XCTAssertNotNil(testShoppingItem1.recordId)
		XCTAssertNotNil(testShoppingItem2.recordId)
	}

	func testUpdateLocalShoppingListFailOnUpdateList() throws {
		let testShoppingList = TestShoppingList()
		let testShoppingItem1 = TestShoppingItem()
		let testShoppingItem2 = TestShoppingItem()
		testShoppingList.name = "test name"
		testShoppingList.date = 602175855.0
		testShoppingList.items = [testShoppingItem1, testShoppingItem2]
		testShoppingItem1.goodName = "good1"
		testShoppingItem1.storeName = "store1"
		testShoppingItem2.goodName = "good2"
		testShoppingItem2.storeName = "store2"

		var recordsUpdateIteration: Int = 0
		self.utilsStub.onUpdateRecords = { (records, localDb) -> Error? in
			recordsUpdateIteration += 1
			if recordsUpdateIteration == 1 {
				XCTAssertEqual(records.count, 1)
				XCTAssertTrue(localDb)
				let listRecord = records[0]
				let items = listRecord[TestShoppingList.dependentItemsRecordAttribute] as? [CKRecord.Reference] ?? []
				XCTAssertEqual(listRecord.recordType, "testListRecord")
				XCTAssertEqual(listRecord.share, nil)
				XCTAssertEqual(listRecord["name"] as? String, "test name")
				XCTAssertEqual((listRecord["date"] as? Date)?.timeIntervalSinceReferenceDate, 602175855.0)
				XCTAssertEqual(items.count, 2)
				XCTAssertEqual(items[0].recordID.recordName, testShoppingItem1.recordId)
				XCTAssertEqual(items[1].recordID.recordName, testShoppingItem2.recordId)
				return CommonError(description: "test error")
			} else if recordsUpdateIteration == 2 {
				return nil
			} else {
				XCTAssertTrue(false)
				return nil
			}
		}
		do {
			_ = try self.cloudShare.updateItem(item: testShoppingList).getValue(test: self, timeout: 10)
			XCTAssertTrue(false, "error should happened")
		} catch {
			XCTAssertEqual(error.localizedDescription, "test error")
		}
		XCTAssertEqual(recordsUpdateIteration, 1)
	}

	func testUpdateLocalShoppingListFailOnUpdateItems() throws {
		let testShoppingList = TestShoppingList()
		let testShoppingItem1 = TestShoppingItem()
		let testShoppingItem2 = TestShoppingItem()
		testShoppingList.name = "test name"
		testShoppingList.date = 602175855.0
		testShoppingList.items = [testShoppingItem1, testShoppingItem2]
		testShoppingItem1.goodName = "good1"
		testShoppingItem1.storeName = "store1"
		testShoppingItem2.goodName = "good2"
		testShoppingItem2.storeName = "store2"

		var recordsUpdateIteration: Int = 0
		self.utilsStub.onUpdateRecords = { (records, localDb) -> Error? in
			recordsUpdateIteration += 1
			if recordsUpdateIteration == 1 {
				XCTAssertEqual(records.count, 1)
				XCTAssertTrue(localDb)
				let listRecord = records[0]
				let items = listRecord[TestShoppingList.dependentItemsRecordAttribute] as? [CKRecord.Reference] ?? []
				XCTAssertEqual(listRecord.recordType, "testListRecord")
				XCTAssertEqual(listRecord.share, nil)
				XCTAssertEqual(listRecord["name"] as? String, "test name")
				XCTAssertEqual((listRecord["date"] as? Date)?.timeIntervalSinceReferenceDate, 602175855.0)
				XCTAssertEqual(items.count, 2)
				XCTAssertEqual(items[0].recordID.recordName, testShoppingItem1.recordId)
				XCTAssertEqual(items[1].recordID.recordName, testShoppingItem2.recordId)
				return nil
			} else if recordsUpdateIteration == 2 {
				XCTAssertEqual(records.count, 2)
				XCTAssertTrue(localDb)
				XCTAssertEqual(records[0].recordType, "testItemRecord")
				XCTAssertEqual(records[1].recordType, "testItemRecord")
				XCTAssertEqual(records[0].parent?.recordID.recordName, testShoppingList.recordId)
				XCTAssertEqual(records[1].parent?.recordID.recordName, testShoppingList.recordId)
				if records[0]["goodName"] as? String == "good1" {
					XCTAssertEqual(records[0]["goodName"] as? String, "good1")
					XCTAssertEqual(records[0]["storeName"] as? String, "store1")
					XCTAssertEqual(records[1]["goodName"] as? String, "good2")
					XCTAssertEqual(records[1]["storeName"] as? String, "store2")
				} else {
					XCTAssertEqual(records[0]["goodName"] as? String, "good2")
					XCTAssertEqual(records[0]["storeName"] as? String, "store2")
					XCTAssertEqual(records[1]["goodName"] as? String, "good1")
					XCTAssertEqual(records[1]["storeName"] as? String, "store1")
				}
				return CommonError(description: "test error")
			} else {
				XCTAssertTrue(false)
				return nil
			}
		}
		do {
			_ = try self.cloudShare.updateItem(item: testShoppingList).getValue(test: self, timeout: 10)
			XCTAssertTrue(false, "error should happened")
		} catch {
			XCTAssertEqual(error.localizedDescription, "test error")
		}
		XCTAssertEqual(recordsUpdateIteration, 2)
	}

	func testUpdateRemoteShoppingListNoShare() throws {
		let testShoppingList = TestShoppingList()
		let testShoppingItem1 = TestShoppingItem()
		let testShoppingItem2 = TestShoppingItem()
		testShoppingList.isRemote = true
		testShoppingList.recordId = "testListRecord"
		testShoppingList.name = "test name"
		testShoppingList.date = 602175855.0
		testShoppingList.items = [testShoppingItem1, testShoppingItem2]
		testShoppingItem1.recordId = "testItemRecord1"
		testShoppingItem1.goodName = "good1"
		testShoppingItem1.storeName = "store1"
		testShoppingItem2.recordId = "testItemRecord2"
		testShoppingItem2.goodName = "good2"
		testShoppingItem2.storeName = "store2"

		var recordsUpdateIteration: Int = 0
		self.utilsStub.onUpdateRecords = { (records, localDb) -> Error? in
			recordsUpdateIteration += 1
			if recordsUpdateIteration == 1 {
				XCTAssertEqual(records.count, 1)
				XCTAssertTrue(!localDb)
				let listRecord = records[0]
				let items = listRecord[TestShoppingList.dependentItemsRecordAttribute] as? [CKRecord.Reference] ?? []
				XCTAssertEqual(listRecord.recordType, "testListRecord")
				XCTAssertEqual(listRecord.share, nil)
				XCTAssertEqual(listRecord["name"] as? String, "test name")
				XCTAssertEqual((listRecord["date"] as? Date)?.timeIntervalSinceReferenceDate, 602175855.0)
				XCTAssertEqual(items.count, 2)
				XCTAssertEqual(items[0].recordID.recordName, testShoppingItem1.recordId)
				XCTAssertEqual(items[1].recordID.recordName, testShoppingItem2.recordId)
				return nil
			} else if recordsUpdateIteration == 2 {
				XCTAssertEqual(records.count, 2)
				XCTAssertTrue(!localDb)
				XCTAssertEqual(records[0].recordType, "testItemRecord")
				XCTAssertEqual(records[1].recordType, "testItemRecord")
				XCTAssertEqual(records[0].parent?.recordID.recordName, testShoppingList.recordId)
				XCTAssertEqual(records[1].parent?.recordID.recordName, testShoppingList.recordId)
				if records[0]["goodName"] as? String == "good1" {
					XCTAssertEqual(records[0].recordID.recordName, "testItemRecord1")
					XCTAssertEqual(records[0]["goodName"] as? String, "good1")
					XCTAssertEqual(records[0]["storeName"] as? String, "store1")
					XCTAssertEqual(records[1].recordID.recordName, "testItemRecord2")
					XCTAssertEqual(records[1]["goodName"] as? String, "good2")
					XCTAssertEqual(records[1]["storeName"] as? String, "store2")
				} else {
					XCTAssertEqual(records[0].recordID.recordName, "testItemRecord2")
					XCTAssertEqual(records[0]["goodName"] as? String, "good2")
					XCTAssertEqual(records[0]["storeName"] as? String, "store2")
					XCTAssertEqual(records[1].recordID.recordName, "testItemRecord1")
					XCTAssertEqual(records[1]["goodName"] as? String, "good1")
					XCTAssertEqual(records[1]["storeName"] as? String, "store1")
				}
				return nil
			} else {
				XCTAssertTrue(false)
				return nil
			}
		}
		var recordsFetchIteration: Int = 0
		self.utilsStub.onFetchRecords = { (recordIds, localDb) -> ([CKRecord], Error?) in
			recordsFetchIteration += 1
			if recordsFetchIteration == 1 {
				XCTAssertEqual(recordIds.count, 1)
				XCTAssertEqual(recordIds[0].recordName, "testListRecord")
				return (recordIds.map({CKRecord(recordType: TestShoppingList.recordType, recordID: $0)}), nil)
			} else if recordsFetchIteration == 2 {
				XCTAssertEqual(recordIds.count, 2)
				if recordIds[0].recordName == "testItemRecord1" {
					XCTAssertEqual(recordIds[0].recordName, "testItemRecord1")
					XCTAssertEqual(recordIds[1].recordName, "testItemRecord2")
				} else {
					XCTAssertEqual(recordIds[0].recordName, "testItemRecord2")
					XCTAssertEqual(recordIds[1].recordName, "testItemRecord1")
				}
				return (recordIds.map({CKRecord(recordType: TestShoppingItem.recordType, recordID: $0)}), nil)
			} else {
				XCTAssertTrue(false)
				return ([], nil)
			}
		}

		_ = try self.cloudShare.updateItem(item: testShoppingList).getValue(test: self, timeout: 10)
		XCTAssertEqual(recordsUpdateIteration, 2)
		XCTAssertEqual(recordsFetchIteration, 2)
		XCTAssertEqual(testShoppingList.recordId, "testListRecord")
		XCTAssertEqual(testShoppingItem1.recordId, "testItemRecord1")
		XCTAssertEqual(testShoppingItem2.recordId, "testItemRecord2")
	}

	func testUpdateRemoteShoppingListNoShareFailOnFetchList() throws {
		let testShoppingList = TestShoppingList()
		let testShoppingItem1 = TestShoppingItem()
		let testShoppingItem2 = TestShoppingItem()
		testShoppingList.isRemote = true
		testShoppingList.recordId = "testListRecord"
		testShoppingList.name = "test name"
		testShoppingList.date = 602175855.0
		testShoppingList.items = [testShoppingItem1, testShoppingItem2]
		testShoppingItem1.recordId = "testItemRecord1"
		testShoppingItem1.goodName = "good1"
		testShoppingItem1.storeName = "store1"
		testShoppingItem2.recordId = "testItemRecord2"
		testShoppingItem2.goodName = "good2"
		testShoppingItem2.storeName = "store2"

		var recordsUpdateIteration: Int = 0
		self.utilsStub.onUpdateRecords = { (records, localDb) -> Error? in
			recordsUpdateIteration += 1
			XCTAssertTrue(false)
			return nil
		}
		var recordsFetchIteration: Int = 0
		self.utilsStub.onFetchRecords = { (recordIds, localDb) -> ([CKRecord], Error?) in
			recordsFetchIteration += 1
			if recordsFetchIteration == 1 {
				XCTAssertEqual(recordIds.count, 1)
				XCTAssertEqual(recordIds[0].recordName, "testListRecord")
				return (recordIds.map({CKRecord(recordType: TestShoppingList.recordType, recordID: $0)}), CommonError(description: "test error"))
			} else if recordsFetchIteration == 2 {
				XCTAssertTrue(false)
				return ([], nil)
			} else {
				XCTAssertTrue(false)
				return ([], nil)
			}
		}

		do {
			_ = try self.cloudShare.updateItem(item: testShoppingList).getValue(test: self, timeout: 10)
			XCTAssertTrue(false)
		} catch {
			XCTAssertEqual(error.localizedDescription, "test error")
		}
		XCTAssertEqual(recordsUpdateIteration, 0)
		XCTAssertEqual(recordsFetchIteration, 1)
	}

	func testUpdateRemoteShoppingListNoShareFailOnFetchItems() throws {
		let testShoppingList = TestShoppingList()
		let testShoppingItem1 = TestShoppingItem()
		let testShoppingItem2 = TestShoppingItem()
		testShoppingList.isRemote = true
		testShoppingList.recordId = "testListRecord"
		testShoppingList.name = "test name"
		testShoppingList.date = 602175855.0
		testShoppingList.items = [testShoppingItem1, testShoppingItem2]
		testShoppingItem1.recordId = "testItemRecord1"
		testShoppingItem1.goodName = "good1"
		testShoppingItem1.storeName = "store1"
		testShoppingItem2.recordId = "testItemRecord2"
		testShoppingItem2.goodName = "good2"
		testShoppingItem2.storeName = "store2"

		var recordsUpdateIteration: Int = 0
		self.utilsStub.onUpdateRecords = { (records, localDb) -> Error? in
			recordsUpdateIteration += 1
			XCTAssertTrue(false)
			return nil
		}
		var recordsFetchIteration: Int = 0
		self.utilsStub.onFetchRecords = { (recordIds, localDb) -> ([CKRecord], Error?) in
			recordsFetchIteration += 1
			if recordsFetchIteration == 1 {
				XCTAssertEqual(recordIds.count, 1)
				XCTAssertEqual(recordIds[0].recordName, "testListRecord")
				return (recordIds.map({CKRecord(recordType: TestShoppingList.recordType, recordID: $0)}), nil)
			} else if recordsFetchIteration == 2 {
				XCTAssertEqual(recordIds.count, 2)
				if recordIds[0].recordName == "testItemRecord1" {
					XCTAssertEqual(recordIds[0].recordName, "testItemRecord1")
					XCTAssertEqual(recordIds[1].recordName, "testItemRecord2")
				} else {
					XCTAssertEqual(recordIds[0].recordName, "testItemRecord2")
					XCTAssertEqual(recordIds[1].recordName, "testItemRecord1")
				}
				return ([], CommonError(description: "test error"))
			} else {
				XCTAssertTrue(false)
				return ([], nil)
			}
		}

		do {
			_ = try self.cloudShare.updateItem(item: testShoppingList).getValue(test: self, timeout: 10)
			XCTAssertTrue(false)
		} catch {
			XCTAssertEqual(error.localizedDescription, "test error")
		}
		XCTAssertEqual(recordsUpdateIteration, 0)
		XCTAssertEqual(recordsFetchIteration, 2)
	}

	func testUpdateRemoteShoppingListNoShareFailOnUpdateList() throws {
		let testShoppingList = TestShoppingList()
		let testShoppingItem1 = TestShoppingItem()
		let testShoppingItem2 = TestShoppingItem()
		testShoppingList.isRemote = true
		testShoppingList.recordId = "testListRecord"
		testShoppingList.name = "test name"
		testShoppingList.date = 602175855.0
		testShoppingList.items = [testShoppingItem1, testShoppingItem2]
		testShoppingItem1.recordId = "testItemRecord1"
		testShoppingItem1.goodName = "good1"
		testShoppingItem1.storeName = "store1"
		testShoppingItem2.recordId = "testItemRecord2"
		testShoppingItem2.goodName = "good2"
		testShoppingItem2.storeName = "store2"

		var recordsUpdateIteration: Int = 0
		self.utilsStub.onUpdateRecords = { (records, localDb) -> Error? in
			recordsUpdateIteration += 1
			if recordsUpdateIteration == 1 {
				XCTAssertEqual(records.count, 1)
				XCTAssertTrue(!localDb)
				let listRecord = records[0]
				let items = listRecord[TestShoppingList.dependentItemsRecordAttribute] as? [CKRecord.Reference] ?? []
				XCTAssertEqual(listRecord.recordType, "testListRecord")
				XCTAssertEqual(listRecord.share, nil)
				XCTAssertEqual(listRecord["name"] as? String, "test name")
				XCTAssertEqual((listRecord["date"] as? Date)?.timeIntervalSinceReferenceDate, 602175855.0)
				XCTAssertEqual(items.count, 2)
				XCTAssertEqual(items[0].recordID.recordName, testShoppingItem1.recordId)
				XCTAssertEqual(items[1].recordID.recordName, testShoppingItem2.recordId)
				return CommonError(description: "test error")
			} else {
				XCTAssertTrue(false)
				return nil
			}
		}
		var recordsFetchIteration: Int = 0
		self.utilsStub.onFetchRecords = { (recordIds, localDb) -> ([CKRecord], Error?) in
			recordsFetchIteration += 1
			if recordsFetchIteration == 1 {
				XCTAssertEqual(recordIds.count, 1)
				XCTAssertEqual(recordIds[0].recordName, "testListRecord")
				return (recordIds.map({CKRecord(recordType: TestShoppingList.recordType, recordID: $0)}), nil)
			} else if recordsFetchIteration == 2 {
				XCTAssertEqual(recordIds.count, 2)
				if recordIds[0].recordName == "testItemRecord1" {
					XCTAssertEqual(recordIds[0].recordName, "testItemRecord1")
					XCTAssertEqual(recordIds[1].recordName, "testItemRecord2")
				} else {
					XCTAssertEqual(recordIds[0].recordName, "testItemRecord2")
					XCTAssertEqual(recordIds[1].recordName, "testItemRecord1")
				}
				return (recordIds.map({CKRecord(recordType: TestShoppingItem.recordType, recordID: $0)}), nil)
			} else {
				XCTAssertTrue(false)
				return ([], nil)
			}
		}

		do {
			_ = try self.cloudShare.updateItem(item: testShoppingList).getValue(test: self, timeout: 10)
			XCTAssertTrue(false)
		} catch {
			XCTAssertEqual(error.localizedDescription, "test error")
		}
		XCTAssertEqual(recordsUpdateIteration, 1)
		XCTAssertEqual(recordsFetchIteration, 2)
	}

	func testUpdateRemoteShoppingListNoShareFailOnUpdateItems() throws {
		let testShoppingList = TestShoppingList()
		let testShoppingItem1 = TestShoppingItem()
		let testShoppingItem2 = TestShoppingItem()
		testShoppingList.isRemote = true
		testShoppingList.recordId = "testListRecord"
		testShoppingList.name = "test name"
		testShoppingList.date = 602175855.0
		testShoppingList.items = [testShoppingItem1, testShoppingItem2]
		testShoppingItem1.recordId = "testItemRecord1"
		testShoppingItem1.goodName = "good1"
		testShoppingItem1.storeName = "store1"
		testShoppingItem2.recordId = "testItemRecord2"
		testShoppingItem2.goodName = "good2"
		testShoppingItem2.storeName = "store2"

		var recordsUpdateIteration: Int = 0
		self.utilsStub.onUpdateRecords = { (records, localDb) -> Error? in
			recordsUpdateIteration += 1
			if recordsUpdateIteration == 1 {
				XCTAssertEqual(records.count, 1)
				XCTAssertTrue(!localDb)
				let listRecord = records[0]
				let items = listRecord[TestShoppingList.dependentItemsRecordAttribute] as? [CKRecord.Reference] ?? []
				XCTAssertEqual(listRecord.recordType, "testListRecord")
				XCTAssertEqual(listRecord.share, nil)
				XCTAssertEqual(listRecord["name"] as? String, "test name")
				XCTAssertEqual((listRecord["date"] as? Date)?.timeIntervalSinceReferenceDate, 602175855.0)
				XCTAssertEqual(items.count, 2)
				XCTAssertEqual(items[0].recordID.recordName, testShoppingItem1.recordId)
				XCTAssertEqual(items[1].recordID.recordName, testShoppingItem2.recordId)
				return nil
			} else {
				XCTAssertEqual(records.count, 2)
				XCTAssertTrue(!localDb)
				XCTAssertEqual(records[0].recordType, "testItemRecord")
				XCTAssertEqual(records[1].recordType, "testItemRecord")
				XCTAssertEqual(records[0].parent?.recordID.recordName, testShoppingList.recordId)
				XCTAssertEqual(records[1].parent?.recordID.recordName, testShoppingList.recordId)
				if records[0]["goodName"] as? String == "good1" {
					XCTAssertEqual(records[0].recordID.recordName, "testItemRecord1")
					XCTAssertEqual(records[0]["goodName"] as? String, "good1")
					XCTAssertEqual(records[0]["storeName"] as? String, "store1")
					XCTAssertEqual(records[1].recordID.recordName, "testItemRecord2")
					XCTAssertEqual(records[1]["goodName"] as? String, "good2")
					XCTAssertEqual(records[1]["storeName"] as? String, "store2")
				} else {
					XCTAssertEqual(records[0].recordID.recordName, "testItemRecord2")
					XCTAssertEqual(records[0]["goodName"] as? String, "good2")
					XCTAssertEqual(records[0]["storeName"] as? String, "store2")
					XCTAssertEqual(records[1].recordID.recordName, "testItemRecord1")
					XCTAssertEqual(records[1]["goodName"] as? String, "good1")
					XCTAssertEqual(records[1]["storeName"] as? String, "store1")
				}
				return CommonError(description: "test error")
			}
		}
		var recordsFetchIteration: Int = 0
		self.utilsStub.onFetchRecords = { (recordIds, localDb) -> ([CKRecord], Error?) in
			recordsFetchIteration += 1
			if recordsFetchIteration == 1 {
				XCTAssertEqual(recordIds.count, 1)
				XCTAssertEqual(recordIds[0].recordName, "testListRecord")
				return (recordIds.map({CKRecord(recordType: TestShoppingList.recordType, recordID: $0)}), nil)
			} else if recordsFetchIteration == 2 {
				XCTAssertEqual(recordIds.count, 2)
				if recordIds[0].recordName == "testItemRecord1" {
					XCTAssertEqual(recordIds[0].recordName, "testItemRecord1")
					XCTAssertEqual(recordIds[1].recordName, "testItemRecord2")
				} else {
					XCTAssertEqual(recordIds[0].recordName, "testItemRecord2")
					XCTAssertEqual(recordIds[1].recordName, "testItemRecord1")
				}
				return (recordIds.map({CKRecord(recordType: TestShoppingItem.recordType, recordID: $0)}), nil)
			} else {
				XCTAssertTrue(false)
				return ([], nil)
			}
		}

		do {
			_ = try self.cloudShare.updateItem(item: testShoppingList).getValue(test: self, timeout: 10)
			XCTAssertTrue(false)
		} catch {
			XCTAssertEqual(error.localizedDescription, "test error")
		}
		XCTAssertEqual(recordsUpdateIteration, 2)
		XCTAssertEqual(recordsFetchIteration, 2)
	}

	func testUpdateRemoteShoppingListWithShare() throws {
		let testShoppingList = TestShoppingList()
		let testShoppingItem1 = TestShoppingItem()
		let testShoppingItem2 = TestShoppingItem()
		testShoppingList.isRemote = true
		testShoppingList.recordId = "testListRecord"
		testShoppingList.name = "test name"
		testShoppingList.date = 602175855.0
		testShoppingList.items = [testShoppingItem1, testShoppingItem2]
		testShoppingItem1.recordId = "testItemRecord1"
		testShoppingItem1.goodName = "good1"
		testShoppingItem1.storeName = "store1"
		testShoppingItem2.recordId = "testItemRecord2"
		testShoppingItem2.goodName = "good2"
		testShoppingItem2.storeName = "store2"

		var recordsUpdateIteration: Int = 0
		self.utilsStub.onUpdateRecords = { (records, localDb) -> Error? in
			recordsUpdateIteration += 1
			if recordsUpdateIteration == 1 {
				XCTAssertEqual(records.count, 2)
				XCTAssertTrue(!localDb)
				let listRecord = records[0]
				let items = listRecord[TestShoppingList.dependentItemsRecordAttribute] as? [CKRecord.Reference] ?? []
				XCTAssertEqual(listRecord.recordType, "testListRecord")
				XCTAssertNotEqual(listRecord.share, nil)
				XCTAssertEqual(listRecord["name"] as? String, "test name")
				XCTAssertEqual((listRecord["date"] as? Date)?.timeIntervalSinceReferenceDate, 602175855.0)
				XCTAssertEqual(records[1].recordType, "cloudkit.share")
				XCTAssertEqual(items.count, 2)
				XCTAssertEqual(items[0].recordID.recordName, testShoppingItem1.recordId)
				XCTAssertEqual(items[1].recordID.recordName, testShoppingItem2.recordId)
				return nil
			} else if recordsUpdateIteration == 2 {
				XCTAssertEqual(records.count, 2)
				XCTAssertTrue(!localDb)
				XCTAssertEqual(records[0].recordType, "testItemRecord")
				XCTAssertEqual(records[1].recordType, "testItemRecord")
				XCTAssertEqual(records[0].parent?.recordID.recordName, testShoppingList.recordId)
				XCTAssertEqual(records[1].parent?.recordID.recordName, testShoppingList.recordId)
				if records[0]["goodName"] as? String == "good1" {
					XCTAssertEqual(records[0].recordID.recordName, "testItemRecord1")
					XCTAssertEqual(records[0]["goodName"] as? String, "good1")
					XCTAssertEqual(records[0]["storeName"] as? String, "store1")
					XCTAssertEqual(records[1].recordID.recordName, "testItemRecord2")
					XCTAssertEqual(records[1]["goodName"] as? String, "good2")
					XCTAssertEqual(records[1]["storeName"] as? String, "store2")
				} else {
					XCTAssertEqual(records[0].recordID.recordName, "testItemRecord2")
					XCTAssertEqual(records[0]["goodName"] as? String, "good2")
					XCTAssertEqual(records[0]["storeName"] as? String, "store2")
					XCTAssertEqual(records[1].recordID.recordName, "testItemRecord1")
					XCTAssertEqual(records[1]["goodName"] as? String, "good1")
					XCTAssertEqual(records[1]["storeName"] as? String, "store1")
				}
				return nil
			} else {
				XCTAssertTrue(false)
				return nil
			}
		}
		var recordsFetchIteration: Int = 0
		self.utilsStub.onFetchRecords = { (recordIds, localDb) -> ([CKRecord], Error?) in
			recordsFetchIteration += 1
			if recordsFetchIteration == 1 {
				XCTAssertEqual(recordIds.count, 1)
				XCTAssertEqual(recordIds[0].recordName, "testListRecord")
				return (recordIds.map({SharedRecord(recordType: TestShoppingList.recordType, recordID: $0)}), nil)
			} else if recordsFetchIteration == 2 {
				XCTAssertEqual(recordIds.count, 1)
				XCTAssertEqual(recordIds[0].recordName, "shareTestRecord")
				return (recordIds.map({CKRecord(recordType: "cloudkit.share", recordID: $0)}), nil)
			} else if recordsFetchIteration == 3 {
				XCTAssertEqual(recordIds.count, 2)
				if recordIds[0].recordName == "testItemRecord1" {
					XCTAssertEqual(recordIds[0].recordName, "testItemRecord1")
					XCTAssertEqual(recordIds[1].recordName, "testItemRecord2")
				} else {
					XCTAssertEqual(recordIds[0].recordName, "testItemRecord2")
					XCTAssertEqual(recordIds[1].recordName, "testItemRecord1")
				}
				return (recordIds.map({CKRecord(recordType: TestShoppingItem.recordType, recordID: $0)}), nil)
			} else {
				XCTAssertTrue(false)
				return ([], nil)
			}
		}
		_ = try self.cloudShare.updateItem(item: testShoppingList).getValue(test: self, timeout: 10)
		XCTAssertEqual(recordsUpdateIteration, 2)
		XCTAssertEqual(recordsFetchIteration, 3)
		XCTAssertEqual(testShoppingList.recordId, "testListRecord")
		XCTAssertEqual(testShoppingItem1.recordId, "testItemRecord1")
		XCTAssertEqual(testShoppingItem2.recordId, "testItemRecord2")
	}

	func testUpdateRemoteShoppingListWithShareFailOnFetchList() throws {
		let testShoppingList = TestShoppingList()
		let testShoppingItem1 = TestShoppingItem()
		let testShoppingItem2 = TestShoppingItem()
		testShoppingList.isRemote = true
		testShoppingList.recordId = "testListRecord"
		testShoppingList.name = "test name"
		testShoppingList.date = 602175855.0
		testShoppingList.items = [testShoppingItem1, testShoppingItem2]
		testShoppingItem1.recordId = "testItemRecord1"
		testShoppingItem1.goodName = "good1"
		testShoppingItem1.storeName = "store1"
		testShoppingItem2.recordId = "testItemRecord2"
		testShoppingItem2.goodName = "good2"
		testShoppingItem2.storeName = "store2"

		var recordsUpdateIteration: Int = 0
		self.utilsStub.onUpdateRecords = { (records, localDb) -> Error? in
			recordsUpdateIteration += 1
			return nil
		}
		var recordsFetchIteration: Int = 0
		self.utilsStub.onFetchRecords = { (recordIds, localDb) -> ([CKRecord], Error?) in
			recordsFetchIteration += 1
			if recordsFetchIteration == 1 {
				XCTAssertEqual(recordIds.count, 1)
				XCTAssertEqual(recordIds[0].recordName, "testListRecord")
				return ([], CommonError(description: "test error"))
			} else {
				XCTAssertTrue(false)
				return ([], nil)
			}
		}
		do {
			_ = try self.cloudShare.updateItem(item: testShoppingList).getValue(test: self, timeout: 10)
			XCTAssertTrue(false, "error should happened")
		} catch {
			XCTAssertEqual(error.localizedDescription, "test error")
		}
		XCTAssertEqual(recordsUpdateIteration, 0)
		XCTAssertEqual(recordsFetchIteration, 1)
	}

	func testUpdateRemoteShoppingListWithShareFailOnFetchShare() throws {
		let testShoppingList = TestShoppingList()
		let testShoppingItem1 = TestShoppingItem()
		let testShoppingItem2 = TestShoppingItem()
		testShoppingList.isRemote = true
		testShoppingList.recordId = "testListRecord"
		testShoppingList.name = "test name"
		testShoppingList.date = 602175855.0
		testShoppingList.items = [testShoppingItem1, testShoppingItem2]
		testShoppingItem1.recordId = "testItemRecord1"
		testShoppingItem1.goodName = "good1"
		testShoppingItem1.storeName = "store1"
		testShoppingItem2.recordId = "testItemRecord2"
		testShoppingItem2.goodName = "good2"
		testShoppingItem2.storeName = "store2"

		var recordsUpdateIteration: Int = 0
		self.utilsStub.onUpdateRecords = { (records, localDb) -> Error? in
			recordsUpdateIteration += 1
			return nil
		}
		var recordsFetchIteration: Int = 0
		self.utilsStub.onFetchRecords = { (recordIds, localDb) -> ([CKRecord], Error?) in
			recordsFetchIteration += 1
			if recordsFetchIteration == 1 {
				XCTAssertEqual(recordIds.count, 1)
				XCTAssertEqual(recordIds[0].recordName, "testListRecord")
				return (recordIds.map({SharedRecord(recordType: TestShoppingList.recordType, recordID: $0)}), nil)
			} else if recordsFetchIteration == 2 {
				XCTAssertEqual(recordIds.count, 1)
				XCTAssertEqual(recordIds[0].recordName, "shareTestRecord")
				return ([], CommonError(description: "test error"))
			} else {
				XCTAssertTrue(false)
				return ([], nil)
			}
		}
		do {
			_ = try self.cloudShare.updateItem(item: testShoppingList).getValue(test: self, timeout: 10)
			XCTAssertTrue(false, "error should happened")
		} catch {
			XCTAssertEqual(error.localizedDescription, "test error")
		}
		XCTAssertEqual(recordsUpdateIteration, 0)
		XCTAssertEqual(recordsFetchIteration, 2)
	}

	func testUpdateRemoteShoppingListWithShareFailOnFetchItems() throws {
		let testShoppingList = TestShoppingList()
		let testShoppingItem1 = TestShoppingItem()
		let testShoppingItem2 = TestShoppingItem()
		testShoppingList.isRemote = true
		testShoppingList.recordId = "testListRecord"
		testShoppingList.name = "test name"
		testShoppingList.date = 602175855.0
		testShoppingList.items = [testShoppingItem1, testShoppingItem2]
		testShoppingItem1.recordId = "testItemRecord1"
		testShoppingItem1.goodName = "good1"
		testShoppingItem1.storeName = "store1"
		testShoppingItem2.recordId = "testItemRecord2"
		testShoppingItem2.goodName = "good2"
		testShoppingItem2.storeName = "store2"

		var recordsUpdateIteration: Int = 0
		self.utilsStub.onUpdateRecords = { (records, localDb) -> Error? in
			recordsUpdateIteration += 1
			return nil
		}
		var recordsFetchIteration: Int = 0
		self.utilsStub.onFetchRecords = { (recordIds, localDb) -> ([CKRecord], Error?) in
			recordsFetchIteration += 1
			if recordsFetchIteration == 1 {
				XCTAssertEqual(recordIds.count, 1)
				XCTAssertEqual(recordIds[0].recordName, "testListRecord")
				return (recordIds.map({SharedRecord(recordType: TestShoppingList.recordType, recordID: $0)}), nil)
			} else if recordsFetchIteration == 2 {
				XCTAssertEqual(recordIds.count, 1)
				XCTAssertEqual(recordIds[0].recordName, "shareTestRecord")
				return (recordIds.map({CKRecord(recordType: "cloudkit.share", recordID: $0)}), nil)
			} else if recordsFetchIteration == 3 {
				XCTAssertEqual(recordIds.count, 2)
				if recordIds[0].recordName == "testItemRecord1" {
					XCTAssertEqual(recordIds[0].recordName, "testItemRecord1")
					XCTAssertEqual(recordIds[1].recordName, "testItemRecord2")
				} else {
					XCTAssertEqual(recordIds[0].recordName, "testItemRecord2")
					XCTAssertEqual(recordIds[1].recordName, "testItemRecord1")
				}
				return ([], CommonError(description: "test error"))
			} else {
				XCTAssertTrue(false)
				return ([], nil)
			}
		}
		do {
			_ = try self.cloudShare.updateItem(item: testShoppingList).getValue(test: self, timeout: 10)
			XCTAssertTrue(false, "error should happened")
		} catch {
			XCTAssertEqual(error.localizedDescription, "test error")
		}
		XCTAssertEqual(recordsUpdateIteration, 0)
		XCTAssertEqual(recordsFetchIteration, 3)
	}

	func testUpdateRemoteShoppingListWithShareFailOnUpdateList() throws {
		let testShoppingList = TestShoppingList()
		let testShoppingItem1 = TestShoppingItem()
		let testShoppingItem2 = TestShoppingItem()
		testShoppingList.isRemote = true
		testShoppingList.recordId = "testListRecord"
		testShoppingList.name = "test name"
		testShoppingList.date = 602175855.0
		testShoppingList.items = [testShoppingItem1, testShoppingItem2]
		testShoppingItem1.recordId = "testItemRecord1"
		testShoppingItem1.goodName = "good1"
		testShoppingItem1.storeName = "store1"
		testShoppingItem2.recordId = "testItemRecord2"
		testShoppingItem2.goodName = "good2"
		testShoppingItem2.storeName = "store2"

		var recordsUpdateIteration: Int = 0
		self.utilsStub.onUpdateRecords = { (records, localDb) -> Error? in
			recordsUpdateIteration += 1
			if recordsUpdateIteration == 1 {
				XCTAssertEqual(records.count, 2)
				XCTAssertTrue(!localDb)
				let listRecord = records[0]
				let items = listRecord[TestShoppingList.dependentItemsRecordAttribute] as? [CKRecord.Reference] ?? []
				XCTAssertEqual(listRecord.recordType, "testListRecord")
				XCTAssertNotEqual(listRecord.share, nil)
				XCTAssertEqual(listRecord["name"] as? String, "test name")
				XCTAssertEqual((listRecord["date"] as? Date)?.timeIntervalSinceReferenceDate, 602175855.0)
				XCTAssertEqual(records[1].recordType, "cloudkit.share")
				XCTAssertEqual(items.count, 2)
				XCTAssertEqual(items[0].recordID.recordName, testShoppingItem1.recordId)
				XCTAssertEqual(items[1].recordID.recordName, testShoppingItem2.recordId)
				return CommonError(description: "test error")
			} else {
				XCTAssertTrue(false)
				return nil
			}
		}
		var recordsFetchIteration: Int = 0
		self.utilsStub.onFetchRecords = { (recordIds, localDb) -> ([CKRecord], Error?) in
			recordsFetchIteration += 1
			if recordsFetchIteration == 1 {
				XCTAssertEqual(recordIds.count, 1)
				XCTAssertEqual(recordIds[0].recordName, "testListRecord")
				return (recordIds.map({SharedRecord(recordType: TestShoppingList.recordType, recordID: $0)}), nil)
			} else if recordsFetchIteration == 2 {
				XCTAssertEqual(recordIds.count, 1)
				XCTAssertEqual(recordIds[0].recordName, "shareTestRecord")
				return (recordIds.map({CKRecord(recordType: "cloudkit.share", recordID: $0)}), nil)
			} else if recordsFetchIteration == 3 {
				XCTAssertEqual(recordIds.count, 2)
				if recordIds[0].recordName == "testItemRecord1" {
					XCTAssertEqual(recordIds[0].recordName, "testItemRecord1")
					XCTAssertEqual(recordIds[1].recordName, "testItemRecord2")
				} else {
					XCTAssertEqual(recordIds[0].recordName, "testItemRecord2")
					XCTAssertEqual(recordIds[1].recordName, "testItemRecord1")
				}
				return (recordIds.map({CKRecord(recordType: TestShoppingItem.recordType, recordID: $0)}), nil)
			} else {
				XCTAssertTrue(false)
				return ([], nil)
			}
		}
		do {
			_ = try self.cloudShare.updateItem(item: testShoppingList).getValue(test: self, timeout: 10)
			XCTAssertTrue(false, "error should happened")
		} catch {
			XCTAssertEqual(error.localizedDescription, "test error")
		}
		XCTAssertEqual(recordsUpdateIteration, 1)
		XCTAssertEqual(recordsFetchIteration, 3)
	}

	func testUpdateRemoteShoppingListWithShareFailOnUpdateItems() throws {
		let testShoppingList = TestShoppingList()
		let testShoppingItem1 = TestShoppingItem()
		let testShoppingItem2 = TestShoppingItem()
		testShoppingList.isRemote = true
		testShoppingList.recordId = "testListRecord"
		testShoppingList.name = "test name"
		testShoppingList.date = 602175855.0
		testShoppingList.items = [testShoppingItem1, testShoppingItem2]
		testShoppingItem1.recordId = "testItemRecord1"
		testShoppingItem1.goodName = "good1"
		testShoppingItem1.storeName = "store1"
		testShoppingItem2.recordId = "testItemRecord2"
		testShoppingItem2.goodName = "good2"
		testShoppingItem2.storeName = "store2"

		var recordsUpdateIteration: Int = 0
		self.utilsStub.onUpdateRecords = { (records, localDb) -> Error? in
			recordsUpdateIteration += 1
			if recordsUpdateIteration == 1 {
				XCTAssertEqual(records.count, 2)
				XCTAssertTrue(!localDb)
				let listRecord = records[0]
				let items = listRecord[TestShoppingList.dependentItemsRecordAttribute] as? [CKRecord.Reference] ?? []
				XCTAssertEqual(listRecord.recordType, "testListRecord")
				XCTAssertNotEqual(listRecord.share, nil)
				XCTAssertEqual(listRecord["name"] as? String, "test name")
				XCTAssertEqual((listRecord["date"] as? Date)?.timeIntervalSinceReferenceDate, 602175855.0)
				XCTAssertEqual(records[1].recordType, "cloudkit.share")
				XCTAssertEqual(items.count, 2)
				XCTAssertEqual(items[0].recordID.recordName, testShoppingItem1.recordId)
				XCTAssertEqual(items[1].recordID.recordName, testShoppingItem2.recordId)
				return nil
			} else if recordsUpdateIteration == 2 {
				XCTAssertEqual(records.count, 2)
				XCTAssertTrue(!localDb)
				XCTAssertEqual(records[0].recordType, "testItemRecord")
				XCTAssertEqual(records[1].recordType, "testItemRecord")
				XCTAssertEqual(records[0].parent?.recordID.recordName, testShoppingList.recordId)
				XCTAssertEqual(records[1].parent?.recordID.recordName, testShoppingList.recordId)
				if records[0]["goodName"] as? String == "good1" {
					XCTAssertEqual(records[0].recordID.recordName, "testItemRecord1")
					XCTAssertEqual(records[0]["goodName"] as? String, "good1")
					XCTAssertEqual(records[0]["storeName"] as? String, "store1")
					XCTAssertEqual(records[1].recordID.recordName, "testItemRecord2")
					XCTAssertEqual(records[1]["goodName"] as? String, "good2")
					XCTAssertEqual(records[1]["storeName"] as? String, "store2")
				} else {
					XCTAssertEqual(records[0].recordID.recordName, "testItemRecord2")
					XCTAssertEqual(records[0]["goodName"] as? String, "good2")
					XCTAssertEqual(records[0]["storeName"] as? String, "store2")
					XCTAssertEqual(records[1].recordID.recordName, "testItemRecord1")
					XCTAssertEqual(records[1]["goodName"] as? String, "good1")
					XCTAssertEqual(records[1]["storeName"] as? String, "store1")
				}
				return CommonError(description: "test error")
			} else {
				XCTAssertTrue(false)
				return nil
			}
		}
		var recordsFetchIteration: Int = 0
		self.utilsStub.onFetchRecords = { (recordIds, localDb) -> ([CKRecord], Error?) in
			recordsFetchIteration += 1
			if recordsFetchIteration == 1 {
				XCTAssertEqual(recordIds.count, 1)
				XCTAssertEqual(recordIds[0].recordName, "testListRecord")
				return (recordIds.map({SharedRecord(recordType: TestShoppingList.recordType, recordID: $0)}), nil)
			} else if recordsFetchIteration == 2 {
				XCTAssertEqual(recordIds.count, 1)
				XCTAssertEqual(recordIds[0].recordName, "shareTestRecord")
				return (recordIds.map({CKRecord(recordType: "cloudkit.share", recordID: $0)}), nil)
			} else if recordsFetchIteration == 3 {
				XCTAssertEqual(recordIds.count, 2)
				if recordIds[0].recordName == "testItemRecord1" {
					XCTAssertEqual(recordIds[0].recordName, "testItemRecord1")
					XCTAssertEqual(recordIds[1].recordName, "testItemRecord2")
				} else {
					XCTAssertEqual(recordIds[0].recordName, "testItemRecord2")
					XCTAssertEqual(recordIds[1].recordName, "testItemRecord1")
				}
				return (recordIds.map({CKRecord(recordType: TestShoppingItem.recordType, recordID: $0)}), nil)
			} else {
				XCTAssertTrue(false)
				return ([], nil)
			}
		}
		do {
			_ = try self.cloudShare.updateItem(item: testShoppingList).getValue(test: self, timeout: 10)
			XCTAssertTrue(false, "error should happened")
		} catch {
			XCTAssertEqual(error.localizedDescription, "test error")
		}
		XCTAssertEqual(recordsUpdateIteration, 2)
		XCTAssertEqual(recordsFetchIteration, 3)
	}
}
