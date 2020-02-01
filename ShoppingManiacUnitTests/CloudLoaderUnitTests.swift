//
//  CloudLoaderUnitTests.swift
//  ShoppingManiacUnitTests
//
//  Created by Dmitry Matyushkin on 2/1/20.
//  Copyright © 2020 Dmitry Matyushkin. All rights reserved.
//

import XCTest
import CloudKit
import RxBlocking
import CoreStore

//swiftlint:disable type_body_length function_body_length

class CloudLoaderUnitTests: XCTestCase {
    
    private let utilsStub = CloudKitUtilsStub()
    private var cloudLoader: CloudLoader!
    
    override func setUp() {
        self.cloudLoader = CloudLoader(cloudKitUtils: self.utilsStub)
        self.utilsStub.cleanup()
        TestDbWrapper.setup()
    }

    override func tearDown() {
        self.cloudLoader = nil
        self.utilsStub.cleanup()
        TestDbWrapper.cleanup()
    }

    func testLoadShare() throws {
        let metadata = TestShareMetadata()
        var fetchRecordCounter: Int = 0
        self.utilsStub.onFetchRecords = { recordIds, localDb -> [CKRecord] in
            fetchRecordCounter += 1
            if fetchRecordCounter == 1 {
                XCTAssert(recordIds.count == 1)
                XCTAssert(!localDb)
                XCTAssert(recordIds[0].recordName == "testShareRecord")
                XCTAssert(recordIds[0].zoneID.zoneName == "testRecordZone")
                XCTAssert(recordIds[0].zoneID.ownerName == "testRecordOwner")
                let record = CKRecord(recordType: CloudKitUtils.listRecordType, recordID: recordIds[0])
                record["name"] = "Test Shopping List"
                record["date"] = Date(timeIntervalSinceReferenceDate: 602175855.0)
                record["items"] = [CKRecord.Reference(recordID: CKRecord.ID(recordName: "testItem1"), action: .none), CKRecord.Reference(recordID: CKRecord.ID(recordName: "testItem2"), action: .none)]
                return [record]
            } else if fetchRecordCounter == 2 {
                XCTAssert(recordIds.count == 2)
                XCTAssert(!localDb)
                XCTAssert(recordIds[0].recordName == "testItem1")
                XCTAssert(recordIds[1].recordName == "testItem2")
                let record1 = CKRecord(recordType: CloudKitUtils.itemRecordType, recordID: recordIds[0])
                record1["goodName"] = "Test good 1"
                record1["storeName"] = "Test store 1"
                let record2 = CKRecord(recordType: CloudKitUtils.itemRecordType, recordID: recordIds[1])
                record2["goodName"] = "Test good 2"
                record2["storeName"] = "Test store 2"
                return [record1, record2]
            } else {
                XCTAssert(false)
                return []
            }
        }
        let shoppingListLink = try self.cloudLoader.loadShare(metadata: metadata).toBlocking().first()!
        let shoppingList = CoreStoreDefaults.dataStack.fetchExisting(shoppingListLink)!
        XCTAssert(shoppingList.name == "Test Shopping List")
        XCTAssert(shoppingList.ownerName == "testRecordOwner")
        XCTAssert(shoppingList.recordid == "testShareRecord")
        XCTAssert(shoppingList.isRemote)
        XCTAssert(shoppingList.date == 602175855.0)
        let items = shoppingList.listItems
        XCTAssert(items.count == 2)
        if items[0].good?.name == "Test good 1" {
            XCTAssert(items[0].recordid == "testItem1")
            XCTAssert(items[0].good?.name == "Test good 1")
            XCTAssert(items[0].store?.name == "Test store 1")
            XCTAssert(items[1].recordid == "testItem2")
            XCTAssert(items[1].good?.name == "Test good 2")
            XCTAssert(items[1].store?.name == "Test store 2")
        } else {
            XCTAssert(items[0].recordid == "testItem2")
            XCTAssert(items[0].good?.name == "Test good 2")
            XCTAssert(items[0].store?.name == "Test store 2")
            XCTAssert(items[1].recordid == "testItem1")
            XCTAssert(items[1].good?.name == "Test good 1")
            XCTAssert(items[1].store?.name == "Test store 1")
        }
    }
}
