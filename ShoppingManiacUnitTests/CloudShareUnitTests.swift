//
//  CloudShareUnitTests.swift
//  ShoppingManiacUnitTests
//
//  Created by Dmitry Matyushkin on 1/31/20.
//  Copyright © 2020 Dmitry Matyushkin. All rights reserved.
//

import XCTest
import RxBlocking
import CoreStore
import CloudKit

//swiftlint:disable type_body_length function_body_length

class CloudShareUnitTests: XCTestCase {

    private let utilsStub = CloudKitUtilsStub()
    private var cloudShare: CloudShare!
    private let stack: DataStack = {
        let stack = DataStack(xcodeModelName: "ShoppingManiac", bundle: Bundle(for: CloudShareUnitTests.self))
        do {
            try stack.addStorageAndWait(InMemoryStore())
        } catch {
            XCTFail("Cannot set up database storage: \(error)")
        }
        return stack
    }()
    
    override func setUp() {
        CoreStoreDefaults.dataStack = self.stack
        self.cloudShare = CloudShare(cloudKitUtils: self.utilsStub)
        self.utilsStub.cleanup()
    }

    override func tearDown() {
        self.cloudShare = nil
        self.utilsStub.cleanup()
        do {
            _ = try CoreStoreDefaults.dataStack.perform(synchronous: { transaction in
                try transaction.deleteAll(From<ShoppingList>())
                try transaction.deleteAll(From<Store>())
                try transaction.deleteAll(From<Good>())
                try transaction.deleteAll(From<Category>())
                try transaction.deleteAll(From<ShoppingListItem>())
            })
        } catch {
            print(error.localizedDescription)
        }
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
                XCTAssert(records.count == 2)
                XCTAssert(localDb)
                let listRecord = records[0]
                XCTAssert(listRecord.recordType == "ShoppingList")
                XCTAssert(listRecord.share != nil)
                XCTAssert(listRecord["name"] as? String == "test name")
                XCTAssert((listRecord["date"] as? Date)?.timeIntervalSinceReferenceDate == 602175855.0)
                XCTAssert(records[1].recordType == "cloudkit.share")
            } else if recordsUpdateIteration == 1 {
                XCTAssert(records.count == 2)
                XCTAssert(localDb)
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
            } else {
                XCTAssert(false)
            }
            recordsUpdateIteration += 1
        }
        let shoppingList = ShoppingList.importShoppingList(fromJsonData: shoppingListJson)!
        let share = try self.cloudShare.shareList(list: shoppingList).toBlocking().first()!
        XCTAssert(share[CKShare.SystemFieldKey.title] as? String == "Shopping list")
        XCTAssert(share[CKShare.SystemFieldKey.shareType] as? String == "org.md.ShoppingManiac")
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
                XCTAssert(records.count == 1)
                XCTAssert(localDb)
                let listRecord = records[0]
                XCTAssert(listRecord.recordType == "ShoppingList")
                XCTAssert(listRecord.share == nil)
                XCTAssert(listRecord["name"] as? String == "test name")
                XCTAssert((listRecord["date"] as? Date)?.timeIntervalSinceReferenceDate == 602175855.0)
            } else if recordsUpdateIteration == 1 {
                XCTAssert(records.count == 2)
                XCTAssert(localDb)
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
            } else {
                XCTAssert(false)
            }
            recordsUpdateIteration += 1
        }
        let shoppingList = ShoppingList.importShoppingList(fromJsonData: shoppingListJson)!
        _ = try self.cloudShare.updateList(list: shoppingList).toBlocking().first()!
    }

    func testUpdateRemoteShoppingListNoShare() throws {
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
                XCTAssert(records.count == 1)
                XCTAssert(!localDb)
                let listRecord = records[0]
                XCTAssert(listRecord.recordType == "ShoppingList")
                XCTAssert(listRecord.share == nil)
                XCTAssert(listRecord["name"] as? String == "test name")
                XCTAssert((listRecord["date"] as? Date)?.timeIntervalSinceReferenceDate == 602175855.0)
            } else if recordsUpdateIteration == 1 {
                XCTAssert(records.count == 2)
                XCTAssert(!localDb)
                XCTAssert(records[0].recordType == "ShoppingListItem")
                XCTAssert(records[1].recordType == "ShoppingListItem")
                if records[0]["goodName"] as? String == "good1" {
                    XCTAssert(records[0].recordID.recordName == "testItemRecord1")
                    XCTAssert(records[0]["goodName"] as? String == "good1")
                    XCTAssert(records[0]["storeName"] as? String == "store1")
                    XCTAssert(records[1].recordID.recordName == "testItemRecord2")
                    XCTAssert(records[1]["goodName"] as? String == "good2")
                    XCTAssert(records[1]["storeName"] as? String == "store2")
                } else {
                    XCTAssert(records[0].recordID.recordName == "testItemRecord2")
                    XCTAssert(records[0]["goodName"] as? String == "good2")
                    XCTAssert(records[0]["storeName"] as? String == "store2")
                    XCTAssert(records[1].recordID.recordName == "testItemRecord1")
                    XCTAssert(records[1]["goodName"] as? String == "good1")
                    XCTAssert(records[1]["storeName"] as? String == "store1")
                }
            } else {
                XCTAssert(false)
            }
            recordsUpdateIteration += 1
        }
        var recordsFetchIteration: Int = 0
        self.utilsStub.onFetchRecords = { (recordIds, localDb) -> [CKRecord] in
            recordsFetchIteration += 1
            if recordsFetchIteration == 1 {
                XCTAssert(recordIds.count == 1)
                XCTAssert(recordIds[0].recordName == "testListRecord")
                return recordIds.map({CKRecord(recordType: CloudKitUtils.listRecordType, recordID: $0)})
            } else if recordsFetchIteration == 2 {
                XCTAssert(recordIds.count == 2)
                if recordIds[0].recordName == "testItemRecord1" {
                    XCTAssert(recordIds[0].recordName == "testItemRecord1")
                    XCTAssert(recordIds[1].recordName == "testItemRecord2")
                } else {
                    XCTAssert(recordIds[0].recordName == "testItemRecord2")
                    XCTAssert(recordIds[1].recordName == "testItemRecord1")
                }
                return recordIds.map({CKRecord(recordType: CloudKitUtils.itemRecordType, recordID: $0)})
            } else {
                XCTAssert(false)
                return []
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
    }
    
    func testUpdateRemoteShoppingListWithShare() throws {
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
                XCTAssert(records.count == 2)
                XCTAssert(!localDb)
                let listRecord = records[0]
                XCTAssert(listRecord.recordType == "ShoppingList")
                XCTAssert(listRecord.share != nil)
                XCTAssert(listRecord["name"] as? String == "test name")
                XCTAssert((listRecord["date"] as? Date)?.timeIntervalSinceReferenceDate == 602175855.0)
                XCTAssert(records[1].recordType == "cloudkit.share")
            } else if recordsUpdateIteration == 1 {
                XCTAssert(records.count == 2)
                XCTAssert(!localDb)
                XCTAssert(records[0].recordType == "ShoppingListItem")
                XCTAssert(records[1].recordType == "ShoppingListItem")
                if records[0]["goodName"] as? String == "good1" {
                    XCTAssert(records[0].recordID.recordName == "testItemRecord1")
                    XCTAssert(records[0]["goodName"] as? String == "good1")
                    XCTAssert(records[0]["storeName"] as? String == "store1")
                    XCTAssert(records[1].recordID.recordName == "testItemRecord2")
                    XCTAssert(records[1]["goodName"] as? String == "good2")
                    XCTAssert(records[1]["storeName"] as? String == "store2")
                } else {
                    XCTAssert(records[0].recordID.recordName == "testItemRecord2")
                    XCTAssert(records[0]["goodName"] as? String == "good2")
                    XCTAssert(records[0]["storeName"] as? String == "store2")
                    XCTAssert(records[1].recordID.recordName == "testItemRecord1")
                    XCTAssert(records[1]["goodName"] as? String == "good1")
                    XCTAssert(records[1]["storeName"] as? String == "store1")
                }
            } else {
                XCTAssert(false)
            }
            recordsUpdateIteration += 1
        }
        var recordsFetchIteration: Int = 0
        self.utilsStub.onFetchRecords = { (recordIds, localDb) -> [CKRecord] in
            recordsFetchIteration += 1
            if recordsFetchIteration == 1 {
                XCTAssert(recordIds.count == 1)
                XCTAssert(recordIds[0].recordName == "testListRecord")
                return recordIds.map({SharedRecord(recordType: CloudKitUtils.listRecordType, recordID: $0)})
            } else if recordsFetchIteration == 2 {
                XCTAssert(recordIds.count == 2)
                if recordIds[0].recordName == "testItemRecord1" {
                    XCTAssert(recordIds[0].recordName == "testItemRecord1")
                    XCTAssert(recordIds[1].recordName == "testItemRecord2")
                } else {
                    XCTAssert(recordIds[0].recordName == "testItemRecord2")
                    XCTAssert(recordIds[1].recordName == "testItemRecord1")
                }
                return recordIds.map({CKRecord(recordType: CloudKitUtils.itemRecordType, recordID: $0)})
            } else if recordsFetchIteration == 3 {
                XCTAssert(recordIds.count == 1)
                XCTAssert(recordIds[0].recordName == "shareTestRecord")
                return recordIds.map({CKRecord(recordType: "cloudkit.share", recordID: $0)})
            } else {
                XCTAssert(false)
                return []
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
    }
}
