//
//  CloudShareOperationsUnitTests.swift
//  ShoppingManiacUnitTests
//
//  Created by Dmitry Matyushkin on 2/4/20.
//  Copyright © 2020 Dmitry Matyushkin. All rights reserved.
//

import XCTest
import CloudKit
import Combine
import CommonError
import DependencyInjection
import CloudKitSync
import CoreStore

// swiftlint:disable type_body_length file_length function_body_length cyclomatic_complexity
class CloudShareOperationsUnitTests: XCTestCase {
	
	private let operations = CloudKitTestOperations()
    private let storage = CloudKitTestTokenStorage()
	private var cloudShare: CloudKitSyncShare!

    override func setUp() {
		DIProvider.shared
			.register(forType: CloudKitSyncOperationsProtocol.self, object: self.operations)
			.register(forType: CloudKitSyncTokenStorageProtocol.self, object: self.storage)
			.register(forType: CloudKitSyncUtilsProtocol.self, dependency: CloudKitSyncUtils.self)
		TestDbWrapper.setup()
        self.operations.cleanup()
        self.storage.cleanup()
		self.cloudShare = CloudKitSyncShare()
    }

    override func tearDown() {
		DIProvider.shared.clear()
		TestDbWrapper.cleanup()
        self.operations.cleanup()
        self.storage.cleanup()
		self.cloudShare = nil
    }
	
	func testShareLocalShoppingListSuccess() throws {
		let shoppingListJson: NSDictionary = [
			"name": "test name",
			"date": "Jan 31, 2020 at 7:04:15 PM",
			"items": [
				[
					"good": "good1",
					"store": "store1"
				],
				[
					"good": "good2",
					"store": "store2"
				]
			]
		]
		self.operations.onAddOperation = { operation, localOperations, sharedOperations in
			if localOperations.count == 1 && sharedOperations.count == 0 {
				guard let operation = operation as? CKModifyRecordsOperation else { fatalError() }
				XCTAssertEqual(operation.recordsToSave?.count, 2)
				let records = operation.recordsToSave ?? []
				let listRecord = records[0]
                XCTAssertEqual(listRecord.recordType, "ShoppingList")
                XCTAssertNotEqual(listRecord.share, nil)
                XCTAssertEqual(listRecord["name"] as? String, "test name")
                XCTAssertEqual((listRecord["date"] as? Date)?.timeIntervalSinceReferenceDate, 602175855.0)
                XCTAssertEqual(records[1].recordType, "cloudkit.share")
				operation.modifyRecordsCompletionBlock?([], [], nil)
			} else if localOperations.count == 2 && sharedOperations.count == 0 {
				guard let operation = operation as? CKModifyRecordsOperation else { fatalError() }
				XCTAssertEqual(operation.recordsToSave?.count, 2)
				let records = operation.recordsToSave ?? []
				XCTAssertEqual(records[0].recordType, "ShoppingListItem")
                XCTAssertEqual(records[1].recordType, "ShoppingListItem")
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
				operation.modifyRecordsCompletionBlock?([], [], nil)
			} else {
				fatalError()
			}
		}
		let shoppingList = ShoppingList.importShoppingList(fromJsonData: shoppingListJson)!
        let share = try self.cloudShare.shareItem(item: shoppingList, shareTitle: "Shopping list", shareType: "org.md.ShoppingManiac").getValue(test: self, timeout: 10)
        XCTAssertEqual(share[CKShare.SystemFieldKey.title] as? String, "Shopping list")
        XCTAssertEqual(share[CKShare.SystemFieldKey.shareType] as? String, "org.md.ShoppingManiac")
		XCTAssertEqual(self.operations.localOperations.count, 2)
		XCTAssertEqual(self.operations.sharedOperations.count, 0)
	}
	
	func testShareLocalShoppingListRetry() throws {
		let shoppingListJson: NSDictionary = [
			"name": "test name",
			"date": "Jan 31, 2020 at 7:04:15 PM",
			"items": [
				[
					"good": "good1",
					"store": "store1"
				],
				[
					"good": "good2",
					"store": "store2"
				]
			]
		]
		self.operations.onAddOperation = { operation, localOperations, sharedOperations in
			if localOperations.count == 1 && sharedOperations.count == 0 {
				guard let operation = operation as? CKModifyRecordsOperation else { fatalError() }
				XCTAssertEqual(operation.recordsToSave?.count, 2)
				let records = operation.recordsToSave ?? []
				let listRecord = records[0]
                XCTAssertEqual(listRecord.recordType, "ShoppingList")
                XCTAssertNotEqual(listRecord.share, nil)
                XCTAssertEqual(listRecord["name"] as? String, "test name")
                XCTAssertEqual((listRecord["date"] as? Date)?.timeIntervalSinceReferenceDate, 602175855.0)
                XCTAssertEqual(records[1].recordType, "cloudkit.share")
				operation.modifyRecordsCompletionBlock?([], [], nil)
			} else if localOperations.count == 2 && sharedOperations.count == 0 {
				guard let operation = operation as? CKModifyRecordsOperation else { fatalError() }
				operation.modifyRecordsCompletionBlock?([], [], CommonError(description: "retry"))
			} else if localOperations.count == 3 && sharedOperations.count == 0 {
				guard let operation = operation as? CKModifyRecordsOperation else { fatalError() }
				XCTAssertEqual(operation.recordsToSave?.count, 2)
				let records = operation.recordsToSave ?? []
				XCTAssertEqual(records[0].recordType, "ShoppingListItem")
                XCTAssertEqual(records[1].recordType, "ShoppingListItem")
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
				operation.modifyRecordsCompletionBlock?([], [], nil)
			} else {
				fatalError()
			}
		}
		let shoppingList = ShoppingList.importShoppingList(fromJsonData: shoppingListJson)!
        let share = try self.cloudShare.shareItem(item: shoppingList, shareTitle: "Shopping list", shareType: "org.md.ShoppingManiac").getValue(test: self, timeout: 10)
        XCTAssertEqual(share[CKShare.SystemFieldKey.title] as? String, "Shopping list")
        XCTAssertEqual(share[CKShare.SystemFieldKey.shareType] as? String, "org.md.ShoppingManiac")
		XCTAssertEqual(self.operations.localOperations.count, 3)
		XCTAssertEqual(self.operations.sharedOperations.count, 0)
	}

	func testUpdateLocalShoppingListSuccess() throws {
		let shoppingListJson: NSDictionary = [
			"name": "test name",
			"date": "Jan 31, 2020 at 7:04:15 PM",
			"items": [
				[
					"good": "good1",
					"store": "store1"
				],
				[
					"good": "good2",
					"store": "store2"
				]
			]
		]
		self.operations.onAddOperation = { operation, localOperations, sharedOperations in
			if localOperations.count == 1 && sharedOperations.count == 0 {
				guard let operation = operation as? CKModifyRecordsOperation else { fatalError() }
				XCTAssertEqual(operation.recordsToSave?.count, 1)
				let records = operation.recordsToSave ?? []
				let listRecord = records[0]
                XCTAssertEqual(listRecord.recordType, "ShoppingList")
                XCTAssertEqual(listRecord.share, nil)
                XCTAssertEqual(listRecord["name"] as? String, "test name")
                XCTAssertEqual((listRecord["date"] as? Date)?.timeIntervalSinceReferenceDate, 602175855.0)
				operation.modifyRecordsCompletionBlock?([], [], nil)
			} else if localOperations.count == 2 && sharedOperations.count == 0 {
				guard let operation = operation as? CKModifyRecordsOperation else { fatalError() }
				XCTAssertEqual(operation.recordsToSave?.count, 2)
				let records = operation.recordsToSave ?? []
				XCTAssertEqual(records[0].recordType, "ShoppingListItem")
                XCTAssertEqual(records[1].recordType, "ShoppingListItem")
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
				operation.modifyRecordsCompletionBlock?([], [], nil)
			} else {
				fatalError()
			}
		}
		let shoppingList = ShoppingList.importShoppingList(fromJsonData: shoppingListJson)!
        _ = try self.cloudShare.updateItem(item: shoppingList).getValue(test: self, timeout: 10)
		XCTAssertEqual(self.operations.localOperations.count, 2)
		XCTAssertEqual(self.operations.sharedOperations.count, 0)
	}
	
	func testUpdateLocalShoppingListRetry() throws {
		let shoppingListJson: NSDictionary = [
			"name": "test name",
			"date": "Jan 31, 2020 at 7:04:15 PM",
			"items": [
				[
					"good": "good1",
					"store": "store1"
				],
				[
					"good": "good2",
					"store": "store2"
				]
			]
		]
		self.operations.onAddOperation = { operation, localOperations, sharedOperations in
			if localOperations.count == 1 && sharedOperations.count == 0 {
				guard let operation = operation as? CKModifyRecordsOperation else { fatalError() }
				operation.modifyRecordsCompletionBlock?([], [], CommonError(description: "retry"))
			} else if localOperations.count == 2 && sharedOperations.count == 0 {
				guard let operation = operation as? CKModifyRecordsOperation else { fatalError() }
				XCTAssertEqual(operation.recordsToSave?.count, 1)
				let records = operation.recordsToSave ?? []
				let listRecord = records[0]
                XCTAssertEqual(listRecord.recordType, "ShoppingList")
                XCTAssertEqual(listRecord.share, nil)
                XCTAssertEqual(listRecord["name"] as? String, "test name")
                XCTAssertEqual((listRecord["date"] as? Date)?.timeIntervalSinceReferenceDate, 602175855.0)
				operation.modifyRecordsCompletionBlock?([], [], nil)
			} else if localOperations.count == 3 && sharedOperations.count == 0 {
				guard let operation = operation as? CKModifyRecordsOperation else { fatalError() }
				XCTAssertEqual(operation.recordsToSave?.count, 2)
				let records = operation.recordsToSave ?? []
				XCTAssertEqual(records[0].recordType, "ShoppingListItem")
                XCTAssertEqual(records[1].recordType, "ShoppingListItem")
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
				operation.modifyRecordsCompletionBlock?([], [], nil)
			} else {
				fatalError()
			}
		}
		let shoppingList = ShoppingList.importShoppingList(fromJsonData: shoppingListJson)!
        _ = try self.cloudShare.updateItem(item: shoppingList).getValue(test: self, timeout: 10)
		XCTAssertEqual(self.operations.localOperations.count, 3)
		XCTAssertEqual(self.operations.sharedOperations.count, 0)
	}
	
	func testUpdateRemoteShoppingListNoShareSuccess() throws {
        let shoppingListJson: NSDictionary = [
            "name": "test name",
            "date": "Jan 31, 2020 at 7:04:15 PM",
			"recordId": "testListRecord",
			"isRemote": true,
            "items": [
                [
					"recordId": "testItemRecord1",
                    "good": "good1",
                    "store": "store1"
                ],
                [
					"recordId": "testItemRecord2",
                    "good": "good2",
                    "store": "store2"
                ]
            ]
        ]
        self.operations.onAddOperation = { operation, localOperations, sharedOperations in
			if localOperations.count == 0 && sharedOperations.count == 1 {
				guard let operation = operation as? CKFetchRecordsOperation else { fatalError() }
				let recordIds = operation.recordIDs ?? []
				XCTAssertEqual(recordIds.count, 1)
				XCTAssertEqual(recordIds[0].recordName, "testListRecord")
				for recordId in recordIds {
					let record = CKRecord(recordType: ShoppingList.recordType, recordID: recordId)
					operation.perRecordCompletionBlock?(record, recordId, nil)
				}
				operation.fetchRecordsCompletionBlock?([:], nil)
			} else if localOperations.count == 0 && sharedOperations.count == 2 {
				guard let operation = operation as? CKFetchRecordsOperation else { fatalError() }
				let recordIds = operation.recordIDs ?? []
				XCTAssertEqual(recordIds.count, 2)
                if recordIds[0].recordName == "testItemRecord1" {
                    XCTAssertEqual(recordIds[0].recordName, "testItemRecord1")
                    XCTAssertEqual(recordIds[1].recordName, "testItemRecord2")
                } else {
                    XCTAssertEqual(recordIds[0].recordName, "testItemRecord2")
                    XCTAssertEqual(recordIds[1].recordName, "testItemRecord1")
                }
				for recordId in recordIds {
					let record = CKRecord(recordType: ShoppingListItem.recordType, recordID: recordId)
					operation.perRecordCompletionBlock?(record, recordId, nil)
				}
				operation.fetchRecordsCompletionBlock?([:], nil)
			} else if localOperations.count == 0 && sharedOperations.count == 3 {
				guard let operation = operation as? CKModifyRecordsOperation else { fatalError() }
				XCTAssertEqual(operation.recordsToSave?.count, 1)
				let records = operation.recordsToSave ?? []
				let listRecord = records[0]
                XCTAssertEqual(listRecord.recordType, "ShoppingList")
                XCTAssertEqual(listRecord.share, nil)
                XCTAssertEqual(listRecord["name"] as? String, "test name")
                XCTAssertEqual((listRecord["date"] as? Date)?.timeIntervalSinceReferenceDate, 602175855.0)
				operation.modifyRecordsCompletionBlock?([], [], nil)
			} else if localOperations.count == 0 && sharedOperations.count == 4 {
				guard let operation = operation as? CKModifyRecordsOperation else { fatalError() }
				XCTAssertEqual(operation.recordsToSave?.count, 2)
				let records = operation.recordsToSave ?? []
				XCTAssertEqual(records[0].recordType, "ShoppingListItem")
                XCTAssertEqual(records[1].recordType, "ShoppingListItem")
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
				operation.modifyRecordsCompletionBlock?([], [], nil)
			} else {
				fatalError()
			}
		}
        
        let shoppingList = ShoppingList.importShoppingList(fromJsonData: shoppingListJson)!

		_ = try self.cloudShare.updateItem(item: shoppingList).getValue(test: self, timeout: 10)
        XCTAssertEqual(self.operations.localOperations.count, 0)
		XCTAssertEqual(self.operations.sharedOperations.count, 4)
    }
	
	func testUpdateRemoteShoppingListNoShareRetry() throws {
        let shoppingListJson: NSDictionary = [
            "name": "test name",
            "date": "Jan 31, 2020 at 7:04:15 PM",
			"recordId": "testListRecord",
			"isRemote": true,
            "items": [
                [
					"recordId": "testItemRecord1",
                    "good": "good1",
                    "store": "store1"
                ],
                [
					"recordId": "testItemRecord2",
                    "good": "good2",
                    "store": "store2"
                ]
            ]
        ]
        self.operations.onAddOperation = { operation, localOperations, sharedOperations in
			if localOperations.count == 0 && sharedOperations.count == 1 {
				guard let operation = operation as? CKFetchRecordsOperation else { fatalError() }
				let recordIds = operation.recordIDs ?? []
				XCTAssertEqual(recordIds.count, 1)
				XCTAssertEqual(recordIds[0].recordName, "testListRecord")
				for recordId in recordIds {
					let record = CKRecord(recordType: ShoppingList.recordType, recordID: recordId)
					operation.perRecordCompletionBlock?(record, recordId, nil)
				}
				operation.fetchRecordsCompletionBlock?([:], nil)
			} else if localOperations.count == 0 && sharedOperations.count == 2 {
				guard let operation = operation as? CKFetchRecordsOperation else { fatalError() }
				operation.fetchRecordsCompletionBlock?([:], CommonError(description: "retry"))
			} else if localOperations.count == 0 && sharedOperations.count == 3 {
				guard let operation = operation as? CKFetchRecordsOperation else { fatalError() }
				let recordIds = operation.recordIDs ?? []
				XCTAssertEqual(recordIds.count, 2)
                if recordIds[0].recordName == "testItemRecord1" {
                    XCTAssertEqual(recordIds[0].recordName, "testItemRecord1")
                    XCTAssertEqual(recordIds[1].recordName, "testItemRecord2")
                } else {
                    XCTAssertEqual(recordIds[0].recordName, "testItemRecord2")
                    XCTAssertEqual(recordIds[1].recordName, "testItemRecord1")
                }
				for recordId in recordIds {
					let record = CKRecord(recordType: ShoppingListItem.recordType, recordID: recordId)
					operation.perRecordCompletionBlock?(record, recordId, nil)
				}
				operation.fetchRecordsCompletionBlock?([:], nil)
			} else if localOperations.count == 0 && sharedOperations.count == 4 {
				guard let operation = operation as? CKModifyRecordsOperation else { fatalError() }
				XCTAssertEqual(operation.recordsToSave?.count, 1)
				let records = operation.recordsToSave ?? []
				let listRecord = records[0]
                XCTAssertEqual(listRecord.recordType, "ShoppingList")
                XCTAssertEqual(listRecord.share, nil)
                XCTAssertEqual(listRecord["name"] as? String, "test name")
                XCTAssertEqual((listRecord["date"] as? Date)?.timeIntervalSinceReferenceDate, 602175855.0)
				operation.modifyRecordsCompletionBlock?([], [], nil)
			} else if localOperations.count == 0 && sharedOperations.count == 5 {
				guard let operation = operation as? CKModifyRecordsOperation else { fatalError() }
				operation.modifyRecordsCompletionBlock?([], [], CommonError(description: "retry"))
			} else if localOperations.count == 0 && sharedOperations.count == 6 {
				guard let operation = operation as? CKModifyRecordsOperation else { fatalError() }
				XCTAssertEqual(operation.recordsToSave?.count, 2)
				let records = operation.recordsToSave ?? []
				XCTAssertEqual(records[0].recordType, "ShoppingListItem")
                XCTAssertEqual(records[1].recordType, "ShoppingListItem")
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
				operation.modifyRecordsCompletionBlock?([], [], nil)
			} else {
				fatalError()
			}
		}
        
        let shoppingList = ShoppingList.importShoppingList(fromJsonData: shoppingListJson)!

        _ = try self.cloudShare.updateItem(item: shoppingList).getValue(test: self, timeout: 10)
        XCTAssertEqual(self.operations.localOperations.count, 0)
		XCTAssertEqual(self.operations.sharedOperations.count, 6)
    }
	
	func testUpdateRemoteShoppingListHasShareSuccess() throws {
        let shoppingListJson: NSDictionary = [
            "name": "test name",
            "date": "Jan 31, 2020 at 7:04:15 PM",
			"recordId": "testListRecord",
			"isRemote": true,
            "items": [
                [
					"recordId": "testItemRecord1",
                    "good": "good1",
                    "store": "store1"
                ],
                [
					"recordId": "testItemRecord2",
                    "good": "good2",
                    "store": "store2"
                ]
            ]
        ]
        self.operations.onAddOperation = { operation, localOperations, sharedOperations in
			if localOperations.count == 0 && sharedOperations.count == 1 {
				guard let operation = operation as? CKFetchRecordsOperation else { fatalError() }
				let recordIds = operation.recordIDs ?? []
				XCTAssertEqual(recordIds.count, 1)
				XCTAssertEqual(recordIds[0].recordName, "testListRecord")
				for recordId in recordIds {
					let record = SharedRecord(recordType: ShoppingList.recordType, recordID: recordId)
					operation.perRecordCompletionBlock?(record, recordId, nil)
				}
				operation.fetchRecordsCompletionBlock?([:], nil)
			} else if localOperations.count == 0 && sharedOperations.count == 2 {
				guard let operation = operation as? CKFetchRecordsOperation else { fatalError() }
				let recordIds = operation.recordIDs ?? []
				XCTAssertEqual(recordIds.count, 1)
                XCTAssertEqual(recordIds[0].recordName, "shareTestRecord")
				for recordId in recordIds {
					let record = CKRecord(recordType: "cloudkit.share", recordID: recordId)
					operation.perRecordCompletionBlock?(record, recordId, nil)
				}
				operation.fetchRecordsCompletionBlock?([:], nil)
			} else if localOperations.count == 0 && sharedOperations.count == 3 {
				guard let operation = operation as? CKFetchRecordsOperation else { fatalError() }
				let recordIds = operation.recordIDs ?? []
				XCTAssertEqual(recordIds.count, 2)
                if recordIds[0].recordName == "testItemRecord1" {
                    XCTAssertEqual(recordIds[0].recordName, "testItemRecord1")
                    XCTAssertEqual(recordIds[1].recordName, "testItemRecord2")
                } else {
                    XCTAssertEqual(recordIds[0].recordName, "testItemRecord2")
                    XCTAssertEqual(recordIds[1].recordName, "testItemRecord1")
                }
				for recordId in recordIds {
					let record = CKRecord(recordType: ShoppingListItem.recordType, recordID: recordId)
					operation.perRecordCompletionBlock?(record, recordId, nil)
				}
				operation.fetchRecordsCompletionBlock?([:], nil)
			} else if localOperations.count == 0 && sharedOperations.count == 4 {
				guard let operation = operation as? CKModifyRecordsOperation else { fatalError() }
				XCTAssertEqual(operation.recordsToSave?.count, 2)
				let records = operation.recordsToSave ?? []
				let listRecord = records[0]
                XCTAssertEqual(listRecord.recordType, "ShoppingList")
                XCTAssertNotEqual(listRecord.share, nil)
                XCTAssertEqual(listRecord["name"] as? String, "test name")
                XCTAssertEqual((listRecord["date"] as? Date)?.timeIntervalSinceReferenceDate, 602175855.0)
				XCTAssertEqual(records[1].recordType, "cloudkit.share")
				operation.modifyRecordsCompletionBlock?([], [], nil)
			} else if localOperations.count == 0 && sharedOperations.count == 5 {
				guard let operation = operation as? CKModifyRecordsOperation else { fatalError() }
				XCTAssertEqual(operation.recordsToSave?.count, 2)
				let records = operation.recordsToSave ?? []
				XCTAssertEqual(records[0].recordType, "ShoppingListItem")
                XCTAssertEqual(records[1].recordType, "ShoppingListItem")
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
				operation.modifyRecordsCompletionBlock?([], [], nil)
			} else {
				fatalError()
			}
		}
        
        let shoppingList = ShoppingList.importShoppingList(fromJsonData: shoppingListJson)!

        _ = try self.cloudShare.updateItem(item: shoppingList).getValue(test: self, timeout: 10)
        XCTAssertEqual(self.operations.localOperations.count, 0)
		XCTAssertEqual(self.operations.sharedOperations.count, 5)
    }
	
	func testUpdateRemoteShoppingListHasShareRetry() throws {
        let shoppingListJson: NSDictionary = [
            "name": "test name",
            "date": "Jan 31, 2020 at 7:04:15 PM",
			"recordId": "testListRecord",
			"isRemote": true,
            "items": [
                [
					"recordId": "testItemRecord1",
                    "good": "good1",
                    "store": "store1"
                ],
                [
					"recordId": "testItemRecord2",
                    "good": "good2",
                    "store": "store2"
                ]
            ]
        ]
        self.operations.onAddOperation = { operation, localOperations, sharedOperations in
			if localOperations.count == 0 && sharedOperations.count == 1 {
				guard let operation = operation as? CKFetchRecordsOperation else { fatalError() }
				let recordIds = operation.recordIDs ?? []
				XCTAssertEqual(recordIds.count, 1)
				XCTAssertEqual(recordIds[0].recordName, "testListRecord")
				for recordId in recordIds {
					let record = SharedRecord(recordType: ShoppingList.recordType, recordID: recordId)
					operation.perRecordCompletionBlock?(record, recordId, nil)
				}
				operation.fetchRecordsCompletionBlock?([:], nil)
			} else if localOperations.count == 0 && sharedOperations.count == 2 {
				guard let operation = operation as? CKFetchRecordsOperation else { fatalError() }
				operation.fetchRecordsCompletionBlock?([:], CommonError(description: "retry"))
			} else if localOperations.count == 0 && sharedOperations.count == 3 {
				guard let operation = operation as? CKFetchRecordsOperation else { fatalError() }
				let recordIds = operation.recordIDs ?? []
				XCTAssertEqual(recordIds.count, 1)
                XCTAssertEqual(recordIds[0].recordName, "shareTestRecord")
				for recordId in recordIds {
					let record = CKRecord(recordType: "cloudkit.share", recordID: recordId)
					operation.perRecordCompletionBlock?(record, recordId, nil)
				}
				operation.fetchRecordsCompletionBlock?([:], nil)
			} else if localOperations.count == 0 && sharedOperations.count == 4 {
				guard let operation = operation as? CKFetchRecordsOperation else { fatalError() }
				let recordIds = operation.recordIDs ?? []
				XCTAssertEqual(recordIds.count, 2)
                if recordIds[0].recordName == "testItemRecord1" {
                    XCTAssertEqual(recordIds[0].recordName, "testItemRecord1")
                    XCTAssertEqual(recordIds[1].recordName, "testItemRecord2")
                } else {
                    XCTAssertEqual(recordIds[0].recordName, "testItemRecord2")
                    XCTAssertEqual(recordIds[1].recordName, "testItemRecord1")
                }
				for recordId in recordIds {
					let record = CKRecord(recordType: ShoppingListItem.recordType, recordID: recordId)
					operation.perRecordCompletionBlock?(record, recordId, nil)
				}
				operation.fetchRecordsCompletionBlock?([:], nil)
			} else if localOperations.count == 0 && sharedOperations.count == 5 {
				guard let operation = operation as? CKModifyRecordsOperation else { fatalError() }
				operation.modifyRecordsCompletionBlock?([], [], CommonError(description: "retry"))
			} else if localOperations.count == 0 && sharedOperations.count == 6 {
				guard let operation = operation as? CKModifyRecordsOperation else { fatalError() }
				XCTAssertEqual(operation.recordsToSave?.count, 2)
				let records = operation.recordsToSave ?? []
				let listRecord = records[0]
                XCTAssertEqual(listRecord.recordType, "ShoppingList")
                XCTAssertNotEqual(listRecord.share, nil)
                XCTAssertEqual(listRecord["name"] as? String, "test name")
                XCTAssertEqual((listRecord["date"] as? Date)?.timeIntervalSinceReferenceDate, 602175855.0)
				XCTAssertEqual(records[1].recordType, "cloudkit.share")
				operation.modifyRecordsCompletionBlock?([], [], nil)
			} else if localOperations.count == 0 && sharedOperations.count == 7 {
				guard let operation = operation as? CKModifyRecordsOperation else { fatalError() }
				XCTAssertEqual(operation.recordsToSave?.count, 2)
				let records = operation.recordsToSave ?? []
				XCTAssertEqual(records[0].recordType, "ShoppingListItem")
                XCTAssertEqual(records[1].recordType, "ShoppingListItem")
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
				operation.modifyRecordsCompletionBlock?([], [], nil)
			} else {
				fatalError()
			}
		}
        
        let shoppingList = ShoppingList.importShoppingList(fromJsonData: shoppingListJson)!

        _ = try self.cloudShare.updateItem(item: shoppingList).getValue(test: self, timeout: 10)
        XCTAssertEqual(self.operations.localOperations.count, 0)
		XCTAssertEqual(self.operations.sharedOperations.count, 7)
    }
}
