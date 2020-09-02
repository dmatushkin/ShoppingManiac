//
//  CloudShareUnitTests.swift
//  ShoppingManiacUnitTests
//
//  Created by Dmitry Matyushkin on 1/31/20.
//  Copyright © 2020 Dmitry Matyushkin. All rights reserved.
//

import XCTest
import CoreStore
import CloudKit
import Combine
import DependencyInjection
import CloudKitSync

//swiftlint:disable type_body_length function_body_length

class CloudShareUnitTests: XCTestCase {

    private let utilsStub = CloudKitUtilsStub()
    private var cloudShare: CloudKitSyncShare!
    
    override func setUp() {
		DIProvider.shared
			.register(forType: CloudKitSyncUtilsProtocol.self, lambda: { self.utilsStub })
        self.cloudShare = CloudKitSyncShare()
        self.utilsStub.cleanup()
        TestDbWrapper.setup()
    }

    override func tearDown() {
		DIProvider.shared.clear()
        self.cloudShare = nil
        self.utilsStub.cleanup()
        TestDbWrapper.cleanup()
    }

    func testShareLocalShoppingList() throws {
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
        var recordsUpdateIteration: Int = 0
        self.utilsStub.onUpdateRecords = { records, localDb in
            if recordsUpdateIteration == 0 {
                XCTAssertEqual(records.count, 2)
                XCTAssertTrue(localDb)
                let listRecord = records[0]
                XCTAssertEqual(listRecord.recordType, "ShoppingList")
                XCTAssertNotEqual(listRecord.share, nil)
                XCTAssertEqual(listRecord["name"] as? String, "test name")
                XCTAssertEqual((listRecord["date"] as? Date)?.timeIntervalSinceReferenceDate, 602175855.0)
                XCTAssertEqual(records[1].recordType, "cloudkit.share")
            } else if recordsUpdateIteration == 1 {
                XCTAssertEqual(records.count, 2)
                XCTAssertTrue(localDb)
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
            } else {
                XCTAssertTrue(false)
            }
            recordsUpdateIteration += 1
        }
        let shoppingList = ShoppingList.importShoppingList(fromJsonData: shoppingListJson)!
		let model = try shoppingList.toModel().getValue(test: self, timeout: 10)
		let share = try self.cloudShare.shareItem(item: model, shareTitle: "Shopping list", shareType: "org.md.ShoppingManiac").getValue(test: self, timeout: 10)
        XCTAssertEqual(share[CKShare.SystemFieldKey.title] as? String, "Shopping list")
        XCTAssertEqual(share[CKShare.SystemFieldKey.shareType] as? String, "org.md.ShoppingManiac")
        XCTAssertEqual(recordsUpdateIteration, 2)
    }

	func testShareCrossItemsShoppingList() throws {
        let crossItemsListJson: NSDictionary = [
            "name": "test test",
            "date": "Jan 31, 2020 at 7:04:15 PM",
            "items": [
                [
                    "good": "good1",
                    "store": "store1",
					"isCrossListItem": true
                ],
                [
                    "good": "good2",
                    "store": "store2",
					"isCrossListItem": true
                ]
            ]
        ]
		let shoppingListJson: NSDictionary = [
            "name": "test name",
            "date": "Jan 31, 2020 at 7:04:15 PM",
            "items": []
        ]
        var recordsUpdateIteration: Int = 0
        self.utilsStub.onUpdateRecords = { records, localDb in
            if recordsUpdateIteration == 0 {
                XCTAssertEqual(records.count, 2)
                XCTAssertTrue(localDb)
                let listRecord = records[0]
                XCTAssertEqual(listRecord.recordType, "ShoppingList")
                XCTAssertNotEqual(listRecord.share, nil)
                XCTAssertEqual(listRecord["name"] as? String, "test name")
                XCTAssertEqual((listRecord["date"] as? Date)?.timeIntervalSinceReferenceDate, 602175855.0)
                XCTAssertEqual(records[1].recordType, "cloudkit.share")
            } else if recordsUpdateIteration == 1 {
                XCTAssertEqual(records.count, 2)
                XCTAssertTrue(localDb)
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
            } else {
                XCTAssertTrue(false)
            }
            recordsUpdateIteration += 1
        }
        _ = ShoppingList.importShoppingList(fromJsonData: crossItemsListJson)!
		let shoppingList = ShoppingList.importShoppingList(fromJsonData: shoppingListJson)!
		let model = try shoppingList.toModel().getValue(test: self, timeout: 10)
		let share = try self.cloudShare.shareItem(item: model, shareTitle: "Shopping list", shareType: "org.md.ShoppingManiac").getValue(test: self, timeout: 10)
        XCTAssertEqual(share[CKShare.SystemFieldKey.title] as? String, "Shopping list")
        XCTAssertEqual(share[CKShare.SystemFieldKey.shareType] as? String, "org.md.ShoppingManiac")
        XCTAssertEqual(recordsUpdateIteration, 2)
    }
    
    func testUpdateLocalShoppingList() throws {
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
        var recordsUpdateIteration: Int = 0
        self.utilsStub.onUpdateRecords = { records, localDb in
            if recordsUpdateIteration == 0 {
                XCTAssertEqual(records.count, 1)
                XCTAssertTrue(localDb)
                let listRecord = records[0]
                XCTAssertEqual(listRecord.recordType, "ShoppingList")
                XCTAssertEqual(listRecord.share, nil)
                XCTAssertEqual(listRecord["name"] as? String, "test name")
                XCTAssertEqual((listRecord["date"] as? Date)?.timeIntervalSinceReferenceDate, 602175855.0)
            } else if recordsUpdateIteration == 1 {
                XCTAssertEqual(records.count, 2)
                XCTAssertTrue(localDb)
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
            } else {
                XCTAssertTrue(false)
            }
            recordsUpdateIteration += 1
        }
        let shoppingList = ShoppingList.importShoppingList(fromJsonData: shoppingListJson)!
		let model = try shoppingList.toModel().getValue(test: self, timeout: 10)
        _ = try self.cloudShare.updateItem(item: model).getValue(test: self, timeout: 10)
        XCTAssertEqual(recordsUpdateIteration, 2)
    }

    func testUpdateRemoteShoppingListNoShare() throws {
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
        var recordsUpdateIteration: Int = 0
        self.utilsStub.onUpdateRecords = { records, localDb in
            if recordsUpdateIteration == 0 {
                XCTAssertEqual(records.count, 1)
                XCTAssertTrue(!localDb)
                let listRecord = records[0]
                XCTAssertEqual(listRecord.recordType, "ShoppingList")
                XCTAssertEqual(listRecord.share, nil)
                XCTAssertEqual(listRecord["name"] as? String, "test name")
                XCTAssertEqual((listRecord["date"] as? Date)?.timeIntervalSinceReferenceDate, 602175855.0)
            } else if recordsUpdateIteration == 1 {
                XCTAssertEqual(records.count, 2)
                XCTAssertTrue(!localDb)
                XCTAssertEqual(records[0].recordType, "ShoppingListItem")
                XCTAssertEqual(records[1].recordType, "ShoppingListItem")
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
            } else {
                XCTAssertTrue(false)
            }
            recordsUpdateIteration += 1
        }
        var recordsFetchIteration: Int = 0
        self.utilsStub.onFetchRecords = { (recordIds, localDb) -> [CKRecord] in
            recordsFetchIteration += 1
            if recordsFetchIteration == 1 {
                XCTAssertEqual(recordIds.count, 1)
                XCTAssertEqual(recordIds[0].recordName, "testListRecord")
                return recordIds.map({CKRecord(recordType: CloudKitShoppingList.recordType, recordID: $0)})
            } else if recordsFetchIteration == 2 {
                XCTAssertEqual(recordIds.count, 2)
                if recordIds[0].recordName == "testItemRecord1" {
                    XCTAssertEqual(recordIds[0].recordName, "testItemRecord1")
                    XCTAssertEqual(recordIds[1].recordName, "testItemRecord2")
                } else {
                    XCTAssertEqual(recordIds[0].recordName, "testItemRecord2")
                    XCTAssertEqual(recordIds[1].recordName, "testItemRecord1")
                }
                return recordIds.map({CKRecord(recordType: CloudKitShoppingItem.recordType, recordID: $0)})
            } else {
                XCTAssertTrue(false)
                return []
            }
        }
        let shoppingList = ShoppingList.importShoppingList(fromJsonData: shoppingListJson)!
		let model = try shoppingList.toModel().getValue(test: self, timeout: 10)
		_ = try self.cloudShare.updateItem(item: model).getValue(test: self, timeout: 10)
        XCTAssertEqual(recordsUpdateIteration, 2)
        XCTAssertEqual(recordsFetchIteration, 2)
    }
    
    func testUpdateRemoteShoppingListWithShare() throws {
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
        var recordsUpdateIteration: Int = 0
        self.utilsStub.onUpdateRecords = { records, localDb in
            if recordsUpdateIteration == 0 {
                XCTAssertEqual(records.count, 2)
                XCTAssertTrue(!localDb)
                let listRecord = records[0]
                XCTAssertEqual(listRecord.recordType, "ShoppingList")
                XCTAssertNotEqual(listRecord.share, nil)
                XCTAssertEqual(listRecord["name"] as? String, "test name")
                XCTAssertEqual((listRecord["date"] as? Date)?.timeIntervalSinceReferenceDate, 602175855.0)
                XCTAssertEqual(records[1].recordType, "cloudkit.share")
            } else if recordsUpdateIteration == 1 {
                XCTAssertEqual(records.count, 2)
                XCTAssertTrue(!localDb)
                XCTAssertEqual(records[0].recordType, "ShoppingListItem")
                XCTAssertEqual(records[1].recordType, "ShoppingListItem")
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
            } else {
                XCTAssertTrue(false)
            }
            recordsUpdateIteration += 1
        }
        var recordsFetchIteration: Int = 0
        self.utilsStub.onFetchRecords = { (recordIds, localDb) -> [CKRecord] in
            recordsFetchIteration += 1
            if recordsFetchIteration == 1 {
                XCTAssertEqual(recordIds.count, 1)
                XCTAssertEqual(recordIds[0].recordName, "testListRecord")
				return recordIds.map({SharedRecord(recordType: CloudKitShoppingList.recordType, recordID: $0)})
            } else if recordsFetchIteration == 2 {
				XCTAssertEqual(recordIds.count, 1)
                XCTAssertEqual(recordIds[0].recordName, "shareTestRecord")
                return recordIds.map({CKRecord(recordType: "cloudkit.share", recordID: $0)})
            } else if recordsFetchIteration == 3 {
				XCTAssertEqual(recordIds.count, 2)
                if recordIds[0].recordName == "testItemRecord1" {
                    XCTAssertEqual(recordIds[0].recordName, "testItemRecord1")
                    XCTAssertEqual(recordIds[1].recordName, "testItemRecord2")
                } else {
                    XCTAssertEqual(recordIds[0].recordName, "testItemRecord2")
                    XCTAssertEqual(recordIds[1].recordName, "testItemRecord1")
                }
				return recordIds.map({CKRecord(recordType: CloudKitShoppingItem.recordType, recordID: $0)})
            } else {
                XCTAssertTrue(false)
                return []
            }
        }
        let shoppingList = ShoppingList.importShoppingList(fromJsonData: shoppingListJson)!
		let model = try shoppingList.toModel().getValue(test: self, timeout: 10)
		_ = try self.cloudShare.updateItem(item: model).getValue(test: self, timeout: 10)
        XCTAssertEqual(recordsUpdateIteration, 2)
        XCTAssertEqual(recordsFetchIteration, 3)
    }
}
