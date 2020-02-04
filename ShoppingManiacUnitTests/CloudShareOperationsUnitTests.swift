//
//  CloudShareOperationsUnitTests.swift
//  ShoppingManiacUnitTests
//
//  Created by Dmitry Matyushkin on 2/4/20.
//  Copyright © 2020 Dmitry Matyushkin. All rights reserved.
//

import XCTest
import CloudKit
import RxBlocking

//swiftlint:disable type_body_length file_length function_body_length cyclomatic_complexity
class CloudShareOperationsUnitTests: XCTestCase {
	
	private let operations = CloudKitTestOperations()
    private let storage = CloudKitTestTokenStorage()
	private var cloudShare: CloudShare!

    override func setUp() {
		TestDbWrapper.setup()
        self.operations.cleanup()
        self.storage.cleanup()
		self.cloudShare = CloudShare(cloudKitUtils: CloudKitUtils(operations: self.operations, storage: self.storage))
    }

    override func tearDown() {
		TestDbWrapper.setup()
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
				XCTAssert(operation.recordsToSave?.count == 2)
				let records = operation.recordsToSave ?? []
				let listRecord = records[0]
                XCTAssert(listRecord.recordType == "ShoppingList")
                XCTAssert(listRecord.share != nil)
                XCTAssert(listRecord["name"] as? String == "test name")
                XCTAssert((listRecord["date"] as? Date)?.timeIntervalSinceReferenceDate == 602175855.0)
                XCTAssert(records[1].recordType == "cloudkit.share")
				operation.modifyRecordsCompletionBlock?([], [], nil)
			} else if localOperations.count == 2 && sharedOperations.count == 0 {
				guard let operation = operation as? CKModifyRecordsOperation else { fatalError() }
				XCTAssert(operation.recordsToSave?.count == 2)
				let records = operation.recordsToSave ?? []
				XCTAssert(records[0].recordType == "ShoppingListItem")
                XCTAssert(records[1].recordType == "ShoppingListItem")
                if records[0]["goodName"] as? String == "good1" {
                    XCTAssert(records[0]["goodName"] as? String == "good1")
                    XCTAssert(records[0]["storeName"] as? String == "store1")
                    XCTAssert(records[1]["goodName"] as? String == "good2")
                    XCTAssert(records[1]["storeName"] as? String == "store2")
                } else {
                    XCTAssert(records[0]["goodName"] as? String == "good2")
                    XCTAssert(records[0]["storeName"] as? String == "store2")
                    XCTAssert(records[1]["goodName"] as? String == "good1")
                    XCTAssert(records[1]["storeName"] as? String == "store1")
                }
				operation.modifyRecordsCompletionBlock?([], [], nil)
			} else {
				fatalError()
			}
		}
		let shoppingList = ShoppingList.importShoppingList(fromJsonData: shoppingListJson)!
        let share = try self.cloudShare.shareList(list: shoppingList).toBlocking().first()!
        XCTAssert(share[CKShare.SystemFieldKey.title] as? String == "Shopping list")
        XCTAssert(share[CKShare.SystemFieldKey.shareType] as? String == "org.md.ShoppingManiac")
		XCTAssert(self.operations.localOperations.count == 2)
		XCTAssert(self.operations.sharedOperations.count == 0)
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
				XCTAssert(operation.recordsToSave?.count == 2)
				let records = operation.recordsToSave ?? []
				let listRecord = records[0]
                XCTAssert(listRecord.recordType == "ShoppingList")
                XCTAssert(listRecord.share != nil)
                XCTAssert(listRecord["name"] as? String == "test name")
                XCTAssert((listRecord["date"] as? Date)?.timeIntervalSinceReferenceDate == 602175855.0)
                XCTAssert(records[1].recordType == "cloudkit.share")
				operation.modifyRecordsCompletionBlock?([], [], nil)
			} else if localOperations.count == 2 && sharedOperations.count == 0 {
				guard let operation = operation as? CKModifyRecordsOperation else { fatalError() }
				operation.modifyRecordsCompletionBlock?([], [], CommonError(description: "retry"))
			} else if localOperations.count == 3 && sharedOperations.count == 0 {
				guard let operation = operation as? CKModifyRecordsOperation else { fatalError() }
				XCTAssert(operation.recordsToSave?.count == 2)
				let records = operation.recordsToSave ?? []
				XCTAssert(records[0].recordType == "ShoppingListItem")
                XCTAssert(records[1].recordType == "ShoppingListItem")
                if records[0]["goodName"] as? String == "good1" {
                    XCTAssert(records[0]["goodName"] as? String == "good1")
                    XCTAssert(records[0]["storeName"] as? String == "store1")
                    XCTAssert(records[1]["goodName"] as? String == "good2")
                    XCTAssert(records[1]["storeName"] as? String == "store2")
                } else {
                    XCTAssert(records[0]["goodName"] as? String == "good2")
                    XCTAssert(records[0]["storeName"] as? String == "store2")
                    XCTAssert(records[1]["goodName"] as? String == "good1")
                    XCTAssert(records[1]["storeName"] as? String == "store1")
                }
				operation.modifyRecordsCompletionBlock?([], [], nil)
			} else {
				fatalError()
			}
		}
		let shoppingList = ShoppingList.importShoppingList(fromJsonData: shoppingListJson)!
        let share = try self.cloudShare.shareList(list: shoppingList).toBlocking().first()!
        XCTAssert(share[CKShare.SystemFieldKey.title] as? String == "Shopping list")
        XCTAssert(share[CKShare.SystemFieldKey.shareType] as? String == "org.md.ShoppingManiac")
		XCTAssert(self.operations.localOperations.count == 3)
		XCTAssert(self.operations.sharedOperations.count == 0)
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
				XCTAssert(operation.recordsToSave?.count == 1)
				let records = operation.recordsToSave ?? []
				let listRecord = records[0]
                XCTAssert(listRecord.recordType == "ShoppingList")
                XCTAssert(listRecord.share == nil)
                XCTAssert(listRecord["name"] as? String == "test name")
                XCTAssert((listRecord["date"] as? Date)?.timeIntervalSinceReferenceDate == 602175855.0)
				operation.modifyRecordsCompletionBlock?([], [], nil)
			} else if localOperations.count == 2 && sharedOperations.count == 0 {
				guard let operation = operation as? CKModifyRecordsOperation else { fatalError() }
				XCTAssert(operation.recordsToSave?.count == 2)
				let records = operation.recordsToSave ?? []
				XCTAssert(records[0].recordType == "ShoppingListItem")
                XCTAssert(records[1].recordType == "ShoppingListItem")
                if records[0]["goodName"] as? String == "good1" {
                    XCTAssert(records[0]["goodName"] as? String == "good1")
                    XCTAssert(records[0]["storeName"] as? String == "store1")
                    XCTAssert(records[1]["goodName"] as? String == "good2")
                    XCTAssert(records[1]["storeName"] as? String == "store2")
                } else {
                    XCTAssert(records[0]["goodName"] as? String == "good2")
                    XCTAssert(records[0]["storeName"] as? String == "store2")
                    XCTAssert(records[1]["goodName"] as? String == "good1")
                    XCTAssert(records[1]["storeName"] as? String == "store1")
                }
				operation.modifyRecordsCompletionBlock?([], [], nil)
			} else {
				fatalError()
			}
		}
		let shoppingList = ShoppingList.importShoppingList(fromJsonData: shoppingListJson)!
        _ = try self.cloudShare.updateList(list: shoppingList).toBlocking().first()!
		XCTAssert(self.operations.localOperations.count == 2)
		XCTAssert(self.operations.sharedOperations.count == 0)
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
				XCTAssert(operation.recordsToSave?.count == 1)
				let records = operation.recordsToSave ?? []
				let listRecord = records[0]
                XCTAssert(listRecord.recordType == "ShoppingList")
                XCTAssert(listRecord.share == nil)
                XCTAssert(listRecord["name"] as? String == "test name")
                XCTAssert((listRecord["date"] as? Date)?.timeIntervalSinceReferenceDate == 602175855.0)
				operation.modifyRecordsCompletionBlock?([], [], nil)
			} else if localOperations.count == 3 && sharedOperations.count == 0 {
				guard let operation = operation as? CKModifyRecordsOperation else { fatalError() }
				XCTAssert(operation.recordsToSave?.count == 2)
				let records = operation.recordsToSave ?? []
				XCTAssert(records[0].recordType == "ShoppingListItem")
                XCTAssert(records[1].recordType == "ShoppingListItem")
                if records[0]["goodName"] as? String == "good1" {
                    XCTAssert(records[0]["goodName"] as? String == "good1")
                    XCTAssert(records[0]["storeName"] as? String == "store1")
                    XCTAssert(records[1]["goodName"] as? String == "good2")
                    XCTAssert(records[1]["storeName"] as? String == "store2")
                } else {
                    XCTAssert(records[0]["goodName"] as? String == "good2")
                    XCTAssert(records[0]["storeName"] as? String == "store2")
                    XCTAssert(records[1]["goodName"] as? String == "good1")
                    XCTAssert(records[1]["storeName"] as? String == "store1")
                }
				operation.modifyRecordsCompletionBlock?([], [], nil)
			} else {
				fatalError()
			}
		}
		let shoppingList = ShoppingList.importShoppingList(fromJsonData: shoppingListJson)!
        _ = try self.cloudShare.updateList(list: shoppingList).toBlocking().first()!
		XCTAssert(self.operations.localOperations.count == 3)
		XCTAssert(self.operations.sharedOperations.count == 0)
	}
	
	func testUpdateRemoteShoppingListNoShareSuccess() throws {
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
			if localOperations.count == 0 && sharedOperations.count == 1 {
				guard let operation = operation as? CKFetchRecordsOperation else { fatalError() }
				let recordIds = operation.recordIDs ?? []
				XCTAssert(recordIds.count == 1)
				XCTAssert(recordIds[0].recordName == "testListRecord")
				for recordId in recordIds {
					let record = CKRecord(recordType: CloudKitUtils.listRecordType, recordID: recordId)
					operation.perRecordCompletionBlock?(record, recordId, nil)
				}
				operation.fetchRecordsCompletionBlock?([:], nil)
			} else if localOperations.count == 0 && sharedOperations.count == 2 {
				guard let operation = operation as? CKFetchRecordsOperation else { fatalError() }
				let recordIds = operation.recordIDs ?? []
				XCTAssert(recordIds.count == 2)
                if recordIds[0].recordName == "testItemRecord1" {
                    XCTAssert(recordIds[0].recordName == "testItemRecord1")
                    XCTAssert(recordIds[1].recordName == "testItemRecord2")
                } else {
                    XCTAssert(recordIds[0].recordName == "testItemRecord2")
                    XCTAssert(recordIds[1].recordName == "testItemRecord1")
                }
				for recordId in recordIds {
					let record = CKRecord(recordType: CloudKitUtils.itemRecordType, recordID: recordId)
					operation.perRecordCompletionBlock?(record, recordId, nil)
				}
				operation.fetchRecordsCompletionBlock?([:], nil)
			} else if localOperations.count == 0 && sharedOperations.count == 3 {
				guard let operation = operation as? CKModifyRecordsOperation else { fatalError() }
				XCTAssert(operation.recordsToSave?.count == 1)
				let records = operation.recordsToSave ?? []
				let listRecord = records[0]
                XCTAssert(listRecord.recordType == "ShoppingList")
                XCTAssert(listRecord.share == nil)
                XCTAssert(listRecord["name"] as? String == "test name")
                XCTAssert((listRecord["date"] as? Date)?.timeIntervalSinceReferenceDate == 602175855.0)
				operation.modifyRecordsCompletionBlock?([], [], nil)
			} else if localOperations.count == 0 && sharedOperations.count == 4 {
				guard let operation = operation as? CKModifyRecordsOperation else { fatalError() }
				XCTAssert(operation.recordsToSave?.count == 2)
				let records = operation.recordsToSave ?? []
				XCTAssert(records[0].recordType == "ShoppingListItem")
                XCTAssert(records[1].recordType == "ShoppingListItem")
                if records[0]["goodName"] as? String == "good1" {
                    XCTAssert(records[0]["goodName"] as? String == "good1")
                    XCTAssert(records[0]["storeName"] as? String == "store1")
                    XCTAssert(records[1]["goodName"] as? String == "good2")
                    XCTAssert(records[1]["storeName"] as? String == "store2")
                } else {
                    XCTAssert(records[0]["goodName"] as? String == "good2")
                    XCTAssert(records[0]["storeName"] as? String == "store2")
                    XCTAssert(records[1]["goodName"] as? String == "good1")
                    XCTAssert(records[1]["storeName"] as? String == "store1")
                }
				operation.modifyRecordsCompletionBlock?([], [], nil)
			} else {
				fatalError()
			}
		}
        
        let shoppingList = ShoppingList.importShoppingList(fromJsonData: shoppingListJson)!
        shoppingList.isRemote = true
        shoppingList.recordid = "testListRecord"
        if shoppingList.listItems[0].good?.name == "good1" {
            shoppingList.listItems[0].recordid = "testItemRecord1"
            shoppingList.listItems[1].recordid = "testItemRecord2"
        } else {
            shoppingList.listItems[0].recordid = "testItemRecord2"
            shoppingList.listItems[1].recordid = "testItemRecord1"
        }
        _ = try self.cloudShare.updateList(list: shoppingList).toBlocking().first()!
        XCTAssert(self.operations.localOperations.count == 0)
		XCTAssert(self.operations.sharedOperations.count == 4)
    }
	
	func testUpdateRemoteShoppingListNoShareRetry() throws {
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
			if localOperations.count == 0 && sharedOperations.count == 1 {
				guard let operation = operation as? CKFetchRecordsOperation else { fatalError() }
				let recordIds = operation.recordIDs ?? []
				XCTAssert(recordIds.count == 1)
				XCTAssert(recordIds[0].recordName == "testListRecord")
				for recordId in recordIds {
					let record = CKRecord(recordType: CloudKitUtils.listRecordType, recordID: recordId)
					operation.perRecordCompletionBlock?(record, recordId, nil)
				}
				operation.fetchRecordsCompletionBlock?([:], nil)
			} else if localOperations.count == 0 && sharedOperations.count == 2 {
				guard let operation = operation as? CKFetchRecordsOperation else { fatalError() }
				operation.fetchRecordsCompletionBlock?([:], CommonError(description: "retry"))
			} else if localOperations.count == 0 && sharedOperations.count == 3 {
				guard let operation = operation as? CKFetchRecordsOperation else { fatalError() }
				let recordIds = operation.recordIDs ?? []
				XCTAssert(recordIds.count == 2)
                if recordIds[0].recordName == "testItemRecord1" {
                    XCTAssert(recordIds[0].recordName == "testItemRecord1")
                    XCTAssert(recordIds[1].recordName == "testItemRecord2")
                } else {
                    XCTAssert(recordIds[0].recordName == "testItemRecord2")
                    XCTAssert(recordIds[1].recordName == "testItemRecord1")
                }
				for recordId in recordIds {
					let record = CKRecord(recordType: CloudKitUtils.itemRecordType, recordID: recordId)
					operation.perRecordCompletionBlock?(record, recordId, nil)
				}
				operation.fetchRecordsCompletionBlock?([:], nil)
			} else if localOperations.count == 0 && sharedOperations.count == 4 {
				guard let operation = operation as? CKModifyRecordsOperation else { fatalError() }
				XCTAssert(operation.recordsToSave?.count == 1)
				let records = operation.recordsToSave ?? []
				let listRecord = records[0]
                XCTAssert(listRecord.recordType == "ShoppingList")
                XCTAssert(listRecord.share == nil)
                XCTAssert(listRecord["name"] as? String == "test name")
                XCTAssert((listRecord["date"] as? Date)?.timeIntervalSinceReferenceDate == 602175855.0)
				operation.modifyRecordsCompletionBlock?([], [], nil)
			} else if localOperations.count == 0 && sharedOperations.count == 5 {
				guard let operation = operation as? CKModifyRecordsOperation else { fatalError() }
				operation.modifyRecordsCompletionBlock?([], [], CommonError(description: "retry"))
			} else if localOperations.count == 0 && sharedOperations.count == 6 {
				guard let operation = operation as? CKModifyRecordsOperation else { fatalError() }
				XCTAssert(operation.recordsToSave?.count == 2)
				let records = operation.recordsToSave ?? []
				XCTAssert(records[0].recordType == "ShoppingListItem")
                XCTAssert(records[1].recordType == "ShoppingListItem")
                if records[0]["goodName"] as? String == "good1" {
                    XCTAssert(records[0]["goodName"] as? String == "good1")
                    XCTAssert(records[0]["storeName"] as? String == "store1")
                    XCTAssert(records[1]["goodName"] as? String == "good2")
                    XCTAssert(records[1]["storeName"] as? String == "store2")
                } else {
                    XCTAssert(records[0]["goodName"] as? String == "good2")
                    XCTAssert(records[0]["storeName"] as? String == "store2")
                    XCTAssert(records[1]["goodName"] as? String == "good1")
                    XCTAssert(records[1]["storeName"] as? String == "store1")
                }
				operation.modifyRecordsCompletionBlock?([], [], nil)
			} else {
				fatalError()
			}
		}
        
        let shoppingList = ShoppingList.importShoppingList(fromJsonData: shoppingListJson)!
        shoppingList.isRemote = true
        shoppingList.recordid = "testListRecord"
        if shoppingList.listItems[0].good?.name == "good1" {
            shoppingList.listItems[0].recordid = "testItemRecord1"
            shoppingList.listItems[1].recordid = "testItemRecord2"
        } else {
            shoppingList.listItems[0].recordid = "testItemRecord2"
            shoppingList.listItems[1].recordid = "testItemRecord1"
        }
        _ = try self.cloudShare.updateList(list: shoppingList).toBlocking().first()!
        XCTAssert(self.operations.localOperations.count == 0)
		XCTAssert(self.operations.sharedOperations.count == 6)
    }
	
	func testUpdateRemoteShoppingListHasShareSuccess() throws {
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
			if localOperations.count == 0 && sharedOperations.count == 1 {
				guard let operation = operation as? CKFetchRecordsOperation else { fatalError() }
				let recordIds = operation.recordIDs ?? []
				XCTAssert(recordIds.count == 1)
				XCTAssert(recordIds[0].recordName == "testListRecord")
				for recordId in recordIds {
					let record = SharedRecord(recordType: CloudKitUtils.listRecordType, recordID: recordId)
					operation.perRecordCompletionBlock?(record, recordId, nil)
				}
				operation.fetchRecordsCompletionBlock?([:], nil)
			} else if localOperations.count == 0 && sharedOperations.count == 2 {
				guard let operation = operation as? CKFetchRecordsOperation else { fatalError() }
				let recordIds = operation.recordIDs ?? []
				XCTAssert(recordIds.count == 2)
                if recordIds[0].recordName == "testItemRecord1" {
                    XCTAssert(recordIds[0].recordName == "testItemRecord1")
                    XCTAssert(recordIds[1].recordName == "testItemRecord2")
                } else {
                    XCTAssert(recordIds[0].recordName == "testItemRecord2")
                    XCTAssert(recordIds[1].recordName == "testItemRecord1")
                }
				for recordId in recordIds {
					let record = CKRecord(recordType: CloudKitUtils.itemRecordType, recordID: recordId)
					operation.perRecordCompletionBlock?(record, recordId, nil)
				}
				operation.fetchRecordsCompletionBlock?([:], nil)
			} else if localOperations.count == 0 && sharedOperations.count == 3 {
				guard let operation = operation as? CKFetchRecordsOperation else { fatalError() }
				let recordIds = operation.recordIDs ?? []
				XCTAssert(recordIds.count == 1)
                XCTAssert(recordIds[0].recordName == "shareTestRecord")
				for recordId in recordIds {
					let record = CKRecord(recordType: "cloudkit.share", recordID: recordId)
					operation.perRecordCompletionBlock?(record, recordId, nil)
				}
				operation.fetchRecordsCompletionBlock?([:], nil)
			} else if localOperations.count == 0 && sharedOperations.count == 4 {
				guard let operation = operation as? CKModifyRecordsOperation else { fatalError() }
				XCTAssert(operation.recordsToSave?.count == 2)
				let records = operation.recordsToSave ?? []
				let listRecord = records[0]
                XCTAssert(listRecord.recordType == "ShoppingList")
                XCTAssert(listRecord.share != nil)
                XCTAssert(listRecord["name"] as? String == "test name")
                XCTAssert((listRecord["date"] as? Date)?.timeIntervalSinceReferenceDate == 602175855.0)
				XCTAssert(records[1].recordType == "cloudkit.share")
				operation.modifyRecordsCompletionBlock?([], [], nil)
			} else if localOperations.count == 0 && sharedOperations.count == 5 {
				guard let operation = operation as? CKModifyRecordsOperation else { fatalError() }
				XCTAssert(operation.recordsToSave?.count == 2)
				let records = operation.recordsToSave ?? []
				XCTAssert(records[0].recordType == "ShoppingListItem")
                XCTAssert(records[1].recordType == "ShoppingListItem")
                if records[0]["goodName"] as? String == "good1" {
                    XCTAssert(records[0]["goodName"] as? String == "good1")
                    XCTAssert(records[0]["storeName"] as? String == "store1")
                    XCTAssert(records[1]["goodName"] as? String == "good2")
                    XCTAssert(records[1]["storeName"] as? String == "store2")
                } else {
                    XCTAssert(records[0]["goodName"] as? String == "good2")
                    XCTAssert(records[0]["storeName"] as? String == "store2")
                    XCTAssert(records[1]["goodName"] as? String == "good1")
                    XCTAssert(records[1]["storeName"] as? String == "store1")
                }
				operation.modifyRecordsCompletionBlock?([], [], nil)
			} else {
				fatalError()
			}
		}
        
        let shoppingList = ShoppingList.importShoppingList(fromJsonData: shoppingListJson)!
        shoppingList.isRemote = true
        shoppingList.recordid = "testListRecord"
        if shoppingList.listItems[0].good?.name == "good1" {
            shoppingList.listItems[0].recordid = "testItemRecord1"
            shoppingList.listItems[1].recordid = "testItemRecord2"
        } else {
            shoppingList.listItems[0].recordid = "testItemRecord2"
            shoppingList.listItems[1].recordid = "testItemRecord1"
        }
        _ = try self.cloudShare.updateList(list: shoppingList).toBlocking().first()!
        XCTAssert(self.operations.localOperations.count == 0)
		XCTAssert(self.operations.sharedOperations.count == 5)
    }
	
	func testUpdateRemoteShoppingListHasShareRetry() throws {
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
			if localOperations.count == 0 && sharedOperations.count == 1 {
				guard let operation = operation as? CKFetchRecordsOperation else { fatalError() }
				let recordIds = operation.recordIDs ?? []
				XCTAssert(recordIds.count == 1)
				XCTAssert(recordIds[0].recordName == "testListRecord")
				for recordId in recordIds {
					let record = SharedRecord(recordType: CloudKitUtils.listRecordType, recordID: recordId)
					operation.perRecordCompletionBlock?(record, recordId, nil)
				}
				operation.fetchRecordsCompletionBlock?([:], nil)
			} else if localOperations.count == 0 && sharedOperations.count == 2 {
				guard let operation = operation as? CKFetchRecordsOperation else { fatalError() }
				operation.fetchRecordsCompletionBlock?([:], CommonError(description: "retry"))
			} else if localOperations.count == 0 && sharedOperations.count == 3 {
				guard let operation = operation as? CKFetchRecordsOperation else { fatalError() }
				let recordIds = operation.recordIDs ?? []
				XCTAssert(recordIds.count == 2)
                if recordIds[0].recordName == "testItemRecord1" {
                    XCTAssert(recordIds[0].recordName == "testItemRecord1")
                    XCTAssert(recordIds[1].recordName == "testItemRecord2")
                } else {
                    XCTAssert(recordIds[0].recordName == "testItemRecord2")
                    XCTAssert(recordIds[1].recordName == "testItemRecord1")
                }
				for recordId in recordIds {
					let record = CKRecord(recordType: CloudKitUtils.itemRecordType, recordID: recordId)
					operation.perRecordCompletionBlock?(record, recordId, nil)
				}
				operation.fetchRecordsCompletionBlock?([:], nil)
			} else if localOperations.count == 0 && sharedOperations.count == 4 {
				guard let operation = operation as? CKFetchRecordsOperation else { fatalError() }
				let recordIds = operation.recordIDs ?? []
				XCTAssert(recordIds.count == 1)
                XCTAssert(recordIds[0].recordName == "shareTestRecord")
				for recordId in recordIds {
					let record = CKRecord(recordType: "cloudkit.share", recordID: recordId)
					operation.perRecordCompletionBlock?(record, recordId, nil)
				}
				operation.fetchRecordsCompletionBlock?([:], nil)
			} else if localOperations.count == 0 && sharedOperations.count == 5 {
				guard let operation = operation as? CKModifyRecordsOperation else { fatalError() }
				operation.modifyRecordsCompletionBlock?([], [], CommonError(description: "retry"))
			} else if localOperations.count == 0 && sharedOperations.count == 6 {
				guard let operation = operation as? CKModifyRecordsOperation else { fatalError() }
				XCTAssert(operation.recordsToSave?.count == 2)
				let records = operation.recordsToSave ?? []
				let listRecord = records[0]
                XCTAssert(listRecord.recordType == "ShoppingList")
                XCTAssert(listRecord.share != nil)
                XCTAssert(listRecord["name"] as? String == "test name")
                XCTAssert((listRecord["date"] as? Date)?.timeIntervalSinceReferenceDate == 602175855.0)
				XCTAssert(records[1].recordType == "cloudkit.share")
				operation.modifyRecordsCompletionBlock?([], [], nil)
			} else if localOperations.count == 0 && sharedOperations.count == 7 {
				guard let operation = operation as? CKModifyRecordsOperation else { fatalError() }
				XCTAssert(operation.recordsToSave?.count == 2)
				let records = operation.recordsToSave ?? []
				XCTAssert(records[0].recordType == "ShoppingListItem")
                XCTAssert(records[1].recordType == "ShoppingListItem")
                if records[0]["goodName"] as? String == "good1" {
                    XCTAssert(records[0]["goodName"] as? String == "good1")
                    XCTAssert(records[0]["storeName"] as? String == "store1")
                    XCTAssert(records[1]["goodName"] as? String == "good2")
                    XCTAssert(records[1]["storeName"] as? String == "store2")
                } else {
                    XCTAssert(records[0]["goodName"] as? String == "good2")
                    XCTAssert(records[0]["storeName"] as? String == "store2")
                    XCTAssert(records[1]["goodName"] as? String == "good1")
                    XCTAssert(records[1]["storeName"] as? String == "store1")
                }
				operation.modifyRecordsCompletionBlock?([], [], nil)
			} else {
				fatalError()
			}
		}
        
        let shoppingList = ShoppingList.importShoppingList(fromJsonData: shoppingListJson)!
        shoppingList.isRemote = true
        shoppingList.recordid = "testListRecord"
        if shoppingList.listItems[0].good?.name == "good1" {
            shoppingList.listItems[0].recordid = "testItemRecord1"
            shoppingList.listItems[1].recordid = "testItemRecord2"
        } else {
            shoppingList.listItems[0].recordid = "testItemRecord2"
            shoppingList.listItems[1].recordid = "testItemRecord1"
        }
        _ = try self.cloudShare.updateList(list: shoppingList).toBlocking().first()!
        XCTAssert(self.operations.localOperations.count == 0)
		XCTAssert(self.operations.sharedOperations.count == 7)
    }
}
