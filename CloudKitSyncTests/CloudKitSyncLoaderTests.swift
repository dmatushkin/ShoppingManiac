//
//  CloudKitSyncLoaderTests.swift
//  CloudKitSyncTests
//
//  Created by Dmitry Matyushkin on 8/26/20.
//  Copyright © 2020 Dmitry Matyushkin. All rights reserved.
//

import XCTest
import CloudKit
import CoreStore
import Combine
import DependencyInjection
import CommonError
@testable import CloudKitSync

//swiftlint:disable type_body_length function_body_length superfluous_disable_command

class CloudKitSyncLoaderTests: XCTestCase {

	private let utilsStub = CloudKitSyncUtilsStub()
	private var cloudLoader: CloudKitSyncLoader!

	override func setUp() {
		DIProvider.shared
			.register(forType: CloudKitSyncUtilsProtocol.self, lambda: { self.utilsStub })
        self.cloudLoader = CloudKitSyncLoader()
        self.utilsStub.cleanup()
    }

    override func tearDown() {
		DIProvider.shared.clear()
        self.cloudLoader = nil
        self.utilsStub.cleanup()
    }

	func testLoadShare() throws {
        let metadata = TestShareMetadata()
        var operationsCounter: Int = 0
        self.utilsStub.onFetchRecords = { recordIds, localDb -> [CKRecord] in
            operationsCounter += 1
            if operationsCounter == 2 {
                XCTAssertEqual(recordIds.count, 1)
                XCTAssertTrue(!localDb)
                XCTAssertEqual(recordIds[0].recordName, "testShareRecord")
                XCTAssertEqual(recordIds[0].zoneID.zoneName, "testRecordZone")
                XCTAssertEqual(recordIds[0].zoneID.ownerName, "testRecordOwner")
				let record = CKRecord(recordType: TestShoppingList.recordType, recordID: recordIds[0])
                record["name"] = "Test Shopping List"
                record["date"] = Date(timeIntervalSinceReferenceDate: 602175855.0)
                record["items"] = [CKRecord.Reference(recordID: CKRecord.ID(recordName: "testItem1"), action: .none), CKRecord.Reference(recordID: CKRecord.ID(recordName: "testItem2"), action: .none)]
                return [record]
            } else if operationsCounter == 3 {
                XCTAssertEqual(recordIds.count, 2)
                XCTAssertTrue(!localDb)
                XCTAssertEqual(recordIds[0].recordName, "testItem1")
                XCTAssertEqual(recordIds[1].recordName, "testItem2")
				let record1 = CKRecord(recordType: TestShoppingItem.recordType, recordID: recordIds[0])
                record1["goodName"] = "Test good 1"
                record1["storeName"] = "Test store 1"
                let record2 = CKRecord(recordType: TestShoppingItem.recordType, recordID: recordIds[1])
                record2["goodName"] = "Test good 2"
                record2["storeName"] = "Test store 2"
                return [record1, record2]
            } else {
                XCTAssertTrue(false)
                return []
            }
        }
		self.utilsStub.onAcceptShare = { testMetadata in
			operationsCounter += 1
			XCTAssertEqual(testMetadata, metadata)
			return (testMetadata, nil)
		}
		let shoppingList = try self.cloudLoader.loadShare(metadata: metadata, itemType: TestShoppingList.self).getValue(test: self, timeout: 10)
        XCTAssertEqual(shoppingList.name, "Test Shopping List")
        XCTAssertEqual(shoppingList.ownerName, "testRecordOwner")
        XCTAssertEqual(shoppingList.recordId, "testShareRecord")
        XCTAssertTrue(shoppingList.isRemote)
        XCTAssertEqual(shoppingList.date, 602175855.0)
        let items = shoppingList.items
        XCTAssertEqual(items.count, 2)
		XCTAssertEqual(operationsCounter, 3)
        if items[0].goodName == "Test good 1" {
            XCTAssertEqual(items[0].recordId, "testItem1")
            XCTAssertEqual(items[0].goodName, "Test good 1")
            XCTAssertEqual(items[0].storeName, "Test store 1")
            XCTAssertEqual(items[1].recordId, "testItem2")
            XCTAssertEqual(items[1].goodName, "Test good 2")
            XCTAssertEqual(items[1].storeName, "Test store 2")
        } else {
            XCTAssertEqual(items[0].recordId, "testItem2")
            XCTAssertEqual(items[0].goodName, "Test good 2")
            XCTAssertEqual(items[0].storeName, "Test store 2")
            XCTAssertEqual(items[1].recordId, "testItem1")
            XCTAssertEqual(items[1].goodName, "Test good 1")
            XCTAssertEqual(items[1].storeName, "Test store 1")
        }
    }

	func testFetchChangesLocal() throws {
		self.utilsStub.onFetchDatabaseChanges = { localDb -> [CKRecordZone.ID] in
			XCTAssertTrue(localDb)
			let recordId1 = CKRecordZone.ID(zoneName: "testZone1", ownerName: "testOwner")
			let recordId2 = CKRecordZone.ID(zoneName: "testZone2", ownerName: "testOwner")
			let recordId3 = CKRecordZone.ID(zoneName: "testZone3", ownerName: "testOwner")
			return [recordId1, recordId2, recordId3]
		}
		self.utilsStub.onFetchZoneChanges = { zoneIds -> [CKRecord] in
			XCTAssertEqual(zoneIds[0].zoneName, "testZone1")
			XCTAssertEqual(zoneIds[0].ownerName, "testOwner")
			XCTAssertEqual(zoneIds[1].zoneName, "testZone2")
			XCTAssertEqual(zoneIds[1].ownerName, "testOwner")
			XCTAssertEqual(zoneIds[2].zoneName, "testZone3")
			XCTAssertEqual(zoneIds[2].ownerName, "testOwner")

			let listRecord1 = CKRecord(recordType: TestShoppingList.recordType, recordID: CKRecord.ID(recordName: "testListRecord1", zoneID: zoneIds[0]))
			let listItem11 = CKRecord(recordType: TestShoppingItem.recordType, recordID: CKRecord.ID(recordName: "testItemRecord11", zoneID: zoneIds[0]))
			let listItem12 = CKRecord(recordType: TestShoppingItem.recordType, recordID: CKRecord.ID(recordName: "testItemRecord12", zoneID: zoneIds[0]))
			listRecord1["name"] = "Test Shopping List"
			listRecord1["date"] = Date(timeIntervalSinceReferenceDate: 602175855.0)
			listRecord1["items"] = [CKRecord.Reference(recordID: listItem11.recordID, action: .none), CKRecord.Reference(recordID: listItem12.recordID, action: .none)]
			listItem11["goodName"] = "Test good 11"
			listItem11["storeName"] = "Test store 11"
			listItem11.parent = CKRecord.Reference(recordID: listRecord1.recordID, action: .none)
			listItem12["goodName"] = "Test good 12"
			listItem12["storeName"] = "Test store 12"
			listItem12.parent = CKRecord.Reference(recordID: listRecord1.recordID, action: .none)

			let listRecord2 = CKRecord(recordType: TestShoppingList.recordType, recordID: CKRecord.ID(recordName: "testListRecord2", zoneID: zoneIds[1]))
			let listItem21 = CKRecord(recordType: TestShoppingItem.recordType, recordID: CKRecord.ID(recordName: "testItemRecord21", zoneID: zoneIds[1]))
			let listItem22 = CKRecord(recordType: TestShoppingItem.recordType, recordID: CKRecord.ID(recordName: "testItemRecord22", zoneID: zoneIds[1]))
			listRecord2["name"] = "Test Shopping List 2"
			listRecord2["date"] = Date(timeIntervalSinceReferenceDate: 602175855.0)
			listRecord2["items"] = [CKRecord.Reference(recordID: listItem21.recordID, action: .none), CKRecord.Reference(recordID: listItem22.recordID, action: .none)]
			listItem21["goodName"] = "Test good 21"
			listItem21["storeName"] = "Test store 21"
			listItem21.parent = CKRecord.Reference(recordID: listRecord2.recordID, action: .none)
			listItem22["goodName"] = "Test good 22"
			listItem22["storeName"] = "Test store 22"
			listItem22.parent = CKRecord.Reference(recordID: listRecord2.recordID, action: .none)

			let listRecord3 = CKRecord(recordType: TestShoppingList.recordType, recordID: CKRecord.ID(recordName: "testListRecord3", zoneID: zoneIds[1]))
			listRecord3["name"] = "Test Shopping List 3"
			listRecord3["date"] = Date(timeIntervalSinceReferenceDate: 602175855.0)

			return [listRecord1, listItem11, listItem12, listRecord2, listItem21, listItem22, listRecord3]
		}

		let shoppingLists = try self.cloudLoader.fetchChanges(localDb: true, itemType: TestShoppingList.self).getValue(test: self, timeout: 10)
		let items1 = shoppingLists[0].items.sorted(by: {($0.goodName ?? "") < ($1.goodName ?? "")})
		let items2 = shoppingLists[1].items.sorted(by: {($0.goodName ?? "") < ($1.goodName ?? "")})
		let items3 = shoppingLists[2].items
		XCTAssertEqual(shoppingLists.count, 3)
		XCTAssertEqual(shoppingLists[0].name, "Test Shopping List")
        XCTAssertEqual(shoppingLists[0].ownerName, "testOwner")
        XCTAssertEqual(shoppingLists[0].recordId, "testListRecord1")
        XCTAssertTrue(!shoppingLists[0].isRemote)
        XCTAssertEqual(shoppingLists[0].date, 602175855.0)
		XCTAssertEqual(shoppingLists[1].name, "Test Shopping List 2")
        XCTAssertEqual(shoppingLists[1].ownerName, "testOwner")
        XCTAssertEqual(shoppingLists[1].recordId, "testListRecord2")
        XCTAssertTrue(!shoppingLists[1].isRemote)
        XCTAssertEqual(shoppingLists[1].date, 602175855.0)
		XCTAssertEqual(shoppingLists[2].name, "Test Shopping List 3")
        XCTAssertEqual(shoppingLists[2].ownerName, "testOwner")
        XCTAssertEqual(shoppingLists[2].recordId, "testListRecord3")
        XCTAssertTrue(!shoppingLists[2].isRemote)
        XCTAssertEqual(shoppingLists[2].date, 602175855.0)
		XCTAssertEqual(items1[0].goodName, "Test good 11")
		XCTAssertEqual(items1[0].storeName, "Test store 11")
		XCTAssertEqual(items1[1].goodName, "Test good 12")
		XCTAssertEqual(items1[1].storeName, "Test store 12")
		XCTAssertEqual(items2[0].goodName, "Test good 21")
		XCTAssertEqual(items2[0].storeName, "Test store 21")
		XCTAssertEqual(items2[1].goodName, "Test good 22")
		XCTAssertEqual(items2[1].storeName, "Test store 22")
		XCTAssertEqual(items1.count, 2)
		XCTAssertEqual(items2.count, 2)
		XCTAssertEqual(items3.count, 0)
	}

	func testFetchChangesRemote() throws {
		self.utilsStub.onFetchDatabaseChanges = { localDb -> [CKRecordZone.ID] in
			XCTAssertTrue(!localDb)
			let recordId1 = CKRecordZone.ID(zoneName: "testZone1", ownerName: "testOwner")
			let recordId2 = CKRecordZone.ID(zoneName: "testZone2", ownerName: "testOwner")
			return [recordId1, recordId2]
		}
		self.utilsStub.onFetchZoneChanges = { zoneIds -> [CKRecord] in
			XCTAssertEqual(zoneIds[0].zoneName, "testZone1")
			XCTAssertEqual(zoneIds[0].ownerName, "testOwner")
			XCTAssertEqual(zoneIds[1].zoneName, "testZone2")
			XCTAssertEqual(zoneIds[1].ownerName, "testOwner")

			let listRecord1 = CKRecord(recordType: TestShoppingList.recordType, recordID: CKRecord.ID(recordName: "testListRecord1", zoneID: zoneIds[0]))
			let listItem11 = CKRecord(recordType: TestShoppingItem.recordType, recordID: CKRecord.ID(recordName: "testItemRecord11", zoneID: zoneIds[0]))
			let listItem12 = CKRecord(recordType: TestShoppingItem.recordType, recordID: CKRecord.ID(recordName: "testItemRecord12", zoneID: zoneIds[0]))
			listRecord1["name"] = "Test Shopping List"
			listRecord1["date"] = Date(timeIntervalSinceReferenceDate: 602175855.0)
			listRecord1["items"] = [CKRecord.Reference(recordID: listItem11.recordID, action: .none), CKRecord.Reference(recordID: listItem12.recordID, action: .none)]
			listItem11["goodName"] = "Test good 11"
			listItem11["storeName"] = "Test store 11"
			listItem11.parent = CKRecord.Reference(recordID: listRecord1.recordID, action: .none)
			listItem12["goodName"] = "Test good 12"
			listItem12["storeName"] = "Test store 12"
			listItem12.parent = CKRecord.Reference(recordID: listRecord1.recordID, action: .none)

			let listRecord2 = CKRecord(recordType: TestShoppingList.recordType, recordID: CKRecord.ID(recordName: "testListRecord2", zoneID: zoneIds[1]))
			let listItem21 = CKRecord(recordType: TestShoppingItem.recordType, recordID: CKRecord.ID(recordName: "testItemRecord21", zoneID: zoneIds[1]))
			let listItem22 = CKRecord(recordType: TestShoppingItem.recordType, recordID: CKRecord.ID(recordName: "testItemRecord22", zoneID: zoneIds[1]))
			listRecord2["name"] = "Test Shopping List 2"
			listRecord2["date"] = Date(timeIntervalSinceReferenceDate: 602175855.0)
			listRecord2["items"] = [CKRecord.Reference(recordID: listItem21.recordID, action: .none), CKRecord.Reference(recordID: listItem22.recordID, action: .none)]
			listItem21["goodName"] = "Test good 21"
			listItem21["storeName"] = "Test store 21"
			listItem21.parent = CKRecord.Reference(recordID: listRecord2.recordID, action: .none)
			listItem22["goodName"] = "Test good 22"
			listItem22["storeName"] = "Test store 22"
			listItem22.parent = CKRecord.Reference(recordID: listRecord2.recordID, action: .none)

			return [listRecord1, listItem11, listItem12, listRecord2, listItem21, listItem22]
		}

		let shoppingLists = try self.cloudLoader.fetchChanges(localDb: false, itemType: TestShoppingList.self).getValue(test: self, timeout: 10)
		let items1 = shoppingLists[0].items.sorted(by: {($0.goodName ?? "") < ($1.goodName ?? "")})
		let items2 = shoppingLists[1].items.sorted(by: {($0.goodName ?? "") < ($1.goodName ?? "")})
		XCTAssertEqual(shoppingLists.count, 2)
		XCTAssertEqual(shoppingLists[0].name, "Test Shopping List")
        XCTAssertEqual(shoppingLists[0].ownerName, "testOwner")
        XCTAssertEqual(shoppingLists[0].recordId, "testListRecord1")
        XCTAssertTrue(shoppingLists[0].isRemote)
        XCTAssertEqual(shoppingLists[0].date, 602175855.0)
		XCTAssertEqual(shoppingLists[1].name, "Test Shopping List 2")
        XCTAssertEqual(shoppingLists[1].ownerName, "testOwner")
        XCTAssertEqual(shoppingLists[1].recordId, "testListRecord2")
        XCTAssertTrue(shoppingLists[1].isRemote)
        XCTAssertEqual(shoppingLists[1].date, 602175855.0)
		XCTAssertEqual(items1[0].goodName, "Test good 11")
		XCTAssertEqual(items1[0].storeName, "Test store 11")
		XCTAssertEqual(items1[1].goodName, "Test good 12")
		XCTAssertEqual(items1[1].storeName, "Test store 12")
		XCTAssertEqual(items2[0].goodName, "Test good 21")
		XCTAssertEqual(items2[0].storeName, "Test store 21")
		XCTAssertEqual(items2[1].goodName, "Test good 22")
		XCTAssertEqual(items2[1].storeName, "Test store 22")
		XCTAssertEqual(items1.count, 2)
		XCTAssertEqual(items2.count, 2)
	}
}
