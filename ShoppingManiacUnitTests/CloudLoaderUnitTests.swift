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

//swiftlint:disable type_body_length function_body_length superfluous_disable_command

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
	
	func testFetchChangesLocal() throws {
		self.utilsStub.onFetchDatabaseChanges = { localDb -> ZonesToFetchWrapper in
			XCTAssert(localDb)
			let recordId1 = CKRecordZone.ID(zoneName: "testZone1", ownerName: "testOwner")
			let recordId2 = CKRecordZone.ID(zoneName: "testZone2", ownerName: "testOwner")
			return ZonesToFetchWrapper(localDb: localDb, zoneIds: [recordId1, recordId2])
		}
		self.utilsStub.onFetchZoneChanges = { wrapper -> [CKRecord] in
			XCTAssert(wrapper.localDb)
			XCTAssert(wrapper.zoneIds[0].zoneName == "testZone1")
			XCTAssert(wrapper.zoneIds[0].ownerName == "testOwner")
			XCTAssert(wrapper.zoneIds[1].zoneName == "testZone2")
			XCTAssert(wrapper.zoneIds[1].ownerName == "testOwner")
			
			let listRecord1 = CKRecord(recordType: CloudKitUtils.listRecordType, recordID: CKRecord.ID(recordName: "testListRecord1", zoneID: wrapper.zoneIds[0]))
			let listItem11 = CKRecord(recordType: CloudKitUtils.itemRecordType, recordID: CKRecord.ID(recordName: "testItemRecord11", zoneID: wrapper.zoneIds[0]))
			let listItem12 = CKRecord(recordType: CloudKitUtils.itemRecordType, recordID: CKRecord.ID(recordName: "testItemRecord12", zoneID: wrapper.zoneIds[0]))
			listRecord1["name"] = "Test Shopping List"
			listRecord1["date"] = Date(timeIntervalSinceReferenceDate: 602175855.0)
			listRecord1["items"] = [CKRecord.Reference(recordID: listItem11.recordID, action: .none), CKRecord.Reference(recordID: listItem12.recordID, action: .none)]
			listItem11["goodName"] = "Test good 11"
			listItem11["storeName"] = "Test store 11"
			listItem11.parent = CKRecord.Reference(recordID: listRecord1.recordID, action: .none)
			listItem12["goodName"] = "Test good 12"
			listItem12["storeName"] = "Test store 12"
			listItem12.parent = CKRecord.Reference(recordID: listRecord1.recordID, action: .none)
			
			let listRecord2 = CKRecord(recordType: CloudKitUtils.listRecordType, recordID: CKRecord.ID(recordName: "testListRecord2", zoneID: wrapper.zoneIds[1]))
			let listItem21 = CKRecord(recordType: CloudKitUtils.itemRecordType, recordID: CKRecord.ID(recordName: "testItemRecord21", zoneID: wrapper.zoneIds[1]))
			let listItem22 = CKRecord(recordType: CloudKitUtils.itemRecordType, recordID: CKRecord.ID(recordName: "testItemRecord22", zoneID: wrapper.zoneIds[1]))
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
		
		_ = try self.cloudLoader.fetchChanges(localDb: true).toBlocking().first()
		let shoppingLists = try CoreStoreDefaults.dataStack.fetchAll(From<ShoppingList>().orderBy(.ascending(\.name)))
		let items1 = shoppingLists[0].listItems.sorted(by: {($0.good?.name ?? "") < ($1.good?.name ?? "")})
		let items2 = shoppingLists[1].listItems.sorted(by: {($0.good?.name ?? "") < ($1.good?.name ?? "")})
		XCTAssert(shoppingLists.count == 2)
		XCTAssert(shoppingLists[0].name == "Test Shopping List")
        XCTAssert(shoppingLists[0].ownerName == "testOwner")
        XCTAssert(shoppingLists[0].recordid == "testListRecord1")
        XCTAssert(!shoppingLists[0].isRemote)
        XCTAssert(shoppingLists[0].date == 602175855.0)
		XCTAssert(shoppingLists[1].name == "Test Shopping List 2")
        XCTAssert(shoppingLists[1].ownerName == "testOwner")
        XCTAssert(shoppingLists[1].recordid == "testListRecord2")
        XCTAssert(!shoppingLists[1].isRemote)
        XCTAssert(shoppingLists[1].date == 602175855.0)
		XCTAssert(items1[0].good?.name == "Test good 11")
		XCTAssert(items1[0].store?.name == "Test store 11")
		XCTAssert(items1[1].good?.name == "Test good 12")
		XCTAssert(items1[1].store?.name == "Test store 12")
		XCTAssert(items2[0].good?.name == "Test good 21")
		XCTAssert(items2[0].store?.name == "Test store 21")
		XCTAssert(items2[1].good?.name == "Test good 22")
		XCTAssert(items2[1].store?.name == "Test store 22")
	}
	
	func testFetchChangesRemote() throws {
		self.utilsStub.onFetchDatabaseChanges = { localDb -> ZonesToFetchWrapper in
			XCTAssert(!localDb)
			let recordId1 = CKRecordZone.ID(zoneName: "testZone1", ownerName: "testOwner")
			let recordId2 = CKRecordZone.ID(zoneName: "testZone2", ownerName: "testOwner")
			return ZonesToFetchWrapper(localDb: localDb, zoneIds: [recordId1, recordId2])
		}
		self.utilsStub.onFetchZoneChanges = { wrapper -> [CKRecord] in
			XCTAssert(!wrapper.localDb)
			XCTAssert(wrapper.zoneIds[0].zoneName == "testZone1")
			XCTAssert(wrapper.zoneIds[0].ownerName == "testOwner")
			XCTAssert(wrapper.zoneIds[1].zoneName == "testZone2")
			XCTAssert(wrapper.zoneIds[1].ownerName == "testOwner")
			
			let listRecord1 = CKRecord(recordType: CloudKitUtils.listRecordType, recordID: CKRecord.ID(recordName: "testListRecord1", zoneID: wrapper.zoneIds[0]))
			let listItem11 = CKRecord(recordType: CloudKitUtils.itemRecordType, recordID: CKRecord.ID(recordName: "testItemRecord11", zoneID: wrapper.zoneIds[0]))
			let listItem12 = CKRecord(recordType: CloudKitUtils.itemRecordType, recordID: CKRecord.ID(recordName: "testItemRecord12", zoneID: wrapper.zoneIds[0]))
			listRecord1["name"] = "Test Shopping List"
			listRecord1["date"] = Date(timeIntervalSinceReferenceDate: 602175855.0)
			listRecord1["items"] = [CKRecord.Reference(recordID: listItem11.recordID, action: .none), CKRecord.Reference(recordID: listItem12.recordID, action: .none)]
			listItem11["goodName"] = "Test good 11"
			listItem11["storeName"] = "Test store 11"
			listItem11.parent = CKRecord.Reference(recordID: listRecord1.recordID, action: .none)
			listItem12["goodName"] = "Test good 12"
			listItem12["storeName"] = "Test store 12"
			listItem12.parent = CKRecord.Reference(recordID: listRecord1.recordID, action: .none)
			
			let listRecord2 = CKRecord(recordType: CloudKitUtils.listRecordType, recordID: CKRecord.ID(recordName: "testListRecord2", zoneID: wrapper.zoneIds[1]))
			let listItem21 = CKRecord(recordType: CloudKitUtils.itemRecordType, recordID: CKRecord.ID(recordName: "testItemRecord21", zoneID: wrapper.zoneIds[1]))
			let listItem22 = CKRecord(recordType: CloudKitUtils.itemRecordType, recordID: CKRecord.ID(recordName: "testItemRecord22", zoneID: wrapper.zoneIds[1]))
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
		
		_ = try self.cloudLoader.fetchChanges(localDb: false).toBlocking().first()
		let shoppingLists = try CoreStoreDefaults.dataStack.fetchAll(From<ShoppingList>().orderBy(.ascending(\.name)))
		let items1 = shoppingLists[0].listItems.sorted(by: {($0.good?.name ?? "") < ($1.good?.name ?? "")})
		let items2 = shoppingLists[1].listItems.sorted(by: {($0.good?.name ?? "") < ($1.good?.name ?? "")})
		XCTAssert(shoppingLists.count == 2)
		XCTAssert(shoppingLists[0].name == "Test Shopping List")
        XCTAssert(shoppingLists[0].ownerName == "testOwner")
        XCTAssert(shoppingLists[0].recordid == "testListRecord1")
        XCTAssert(shoppingLists[0].isRemote)
        XCTAssert(shoppingLists[0].date == 602175855.0)
		XCTAssert(shoppingLists[1].name == "Test Shopping List 2")
        XCTAssert(shoppingLists[1].ownerName == "testOwner")
        XCTAssert(shoppingLists[1].recordid == "testListRecord2")
        XCTAssert(shoppingLists[1].isRemote)
        XCTAssert(shoppingLists[1].date == 602175855.0)
		XCTAssert(items1[0].good?.name == "Test good 11")
		XCTAssert(items1[0].store?.name == "Test store 11")
		XCTAssert(items1[1].good?.name == "Test good 12")
		XCTAssert(items1[1].store?.name == "Test store 12")
		XCTAssert(items2[0].good?.name == "Test good 21")
		XCTAssert(items2[0].store?.name == "Test store 21")
		XCTAssert(items2[1].good?.name == "Test good 22")
		XCTAssert(items2[1].store?.name == "Test store 22")
	}
}
