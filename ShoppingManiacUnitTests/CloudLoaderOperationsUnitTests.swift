//
//  CloudLoaderOperationsUnitTests.swift
//  ShoppingManiacUnitTests
//
//  Created by Dmitry Matyushkin on 2/4/20.
//  Copyright © 2020 Dmitry Matyushkin. All rights reserved.
//

import XCTest
import CloudKit
import RxBlocking
import CoreStore

//swiftlint:disable type_body_length file_length function_body_length cyclomatic_complexity
class CloudLoaderOperationsUnitTests: XCTestCase {

    private let operations = CloudKitTestOperations()
    private let storage = CloudKitTestTokenStorage()
	private var cloudLoader: CloudLoader!

    override func setUp() {
		TestDbWrapper.setup()
        self.operations.cleanup()
        self.storage.cleanup()
		self.cloudLoader = CloudLoader(cloudKitUtils: CloudKitUtils(operations: self.operations, storage: self.storage))
    }

    override func tearDown() {
		TestDbWrapper.setup()
        self.operations.cleanup()
        self.storage.cleanup()
		self.cloudLoader = nil
    }
	
	func testLoadShareSuccess() throws {
        let metadata = TestShareMetadata()
		self.operations.onAddOperation = { operation, localOperations, sharedOperations in
			if sharedOperations.count == 1 && localOperations.count == 0 {
				guard let operation = operation as? CKFetchRecordsOperation else { fatalError() }
				let recordIds = operation.recordIDs ?? []
				XCTAssert(recordIds.count == 1)
                XCTAssert(recordIds[0].recordName == "testShareRecord")
                XCTAssert(recordIds[0].zoneID.zoneName == "testRecordZone")
                XCTAssert(recordIds[0].zoneID.ownerName == "testRecordOwner")
				for recordId in recordIds {
					let record = CKRecord(recordType: CloudKitUtils.listRecordType, recordID: recordId)
					record["name"] = "Test Shopping List"
					record["date"] = Date(timeIntervalSinceReferenceDate: 602175855.0)
					record["items"] = [CKRecord.Reference(recordID: CKRecord.ID(recordName: "testItem1"), action: .none), CKRecord.Reference(recordID: CKRecord.ID(recordName: "testItem2"), action: .none)]
					operation.perRecordCompletionBlock?(record, recordId, nil)
				}
				operation.fetchRecordsCompletionBlock?([:], nil)
			} else if sharedOperations.count == 2 && localOperations.count == 0 {
				guard let operation = operation as? CKFetchRecordsOperation else { fatalError() }
				let recordIds = operation.recordIDs ?? []
				XCTAssert(recordIds.count == 2)
                XCTAssert(recordIds[0].recordName == "testItem1")
                XCTAssert(recordIds[1].recordName == "testItem2")
                let record1 = CKRecord(recordType: CloudKitUtils.itemRecordType, recordID: recordIds[0])
                record1["goodName"] = "Test good 1"
                record1["storeName"] = "Test store 1"
                let record2 = CKRecord(recordType: CloudKitUtils.itemRecordType, recordID: recordIds[1])
                record2["goodName"] = "Test good 2"
                record2["storeName"] = "Test store 2"
				operation.perRecordCompletionBlock?(record1, record1.recordID, nil)
				operation.perRecordCompletionBlock?(record2, record2.recordID, nil)
				operation.fetchRecordsCompletionBlock?([:], nil)
			} else {
				fatalError()
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
		XCTAssert(self.operations.localOperations.count == 0)
		XCTAssert(self.operations.sharedOperations.count == 2)
    }
	
	func testLoadShareRetry() throws {
        let metadata = TestShareMetadata()
		self.operations.onAddOperation = { operation, localOperations, sharedOperations in
			if sharedOperations.count == 1 && localOperations.count == 0 {
				guard let operation = operation as? CKFetchRecordsOperation else { fatalError() }
				let recordIds = operation.recordIDs ?? []
				XCTAssert(recordIds.count == 1)
                XCTAssert(recordIds[0].recordName == "testShareRecord")
                XCTAssert(recordIds[0].zoneID.zoneName == "testRecordZone")
                XCTAssert(recordIds[0].zoneID.ownerName == "testRecordOwner")
				for recordId in recordIds {
					let record = CKRecord(recordType: CloudKitUtils.listRecordType, recordID: recordId)
					record["name"] = "Test Shopping List"
					record["date"] = Date(timeIntervalSinceReferenceDate: 602175855.0)
					record["items"] = [CKRecord.Reference(recordID: CKRecord.ID(recordName: "testItem1"), action: .none), CKRecord.Reference(recordID: CKRecord.ID(recordName: "testItem2"), action: .none)]
					operation.perRecordCompletionBlock?(record, recordId, nil)
				}
				operation.fetchRecordsCompletionBlock?([:], nil)
			} else if sharedOperations.count == 2 && localOperations.count == 0 {
				guard let operation = operation as? CKFetchRecordsOperation else { fatalError() }
				operation.fetchRecordsCompletionBlock?([:], CommonError(description: "retry"))
			} else if sharedOperations.count == 3 && localOperations.count == 0 {
				guard let operation = operation as? CKFetchRecordsOperation else { fatalError() }
				let recordIds = operation.recordIDs ?? []
				XCTAssert(recordIds.count == 2)
                XCTAssert(recordIds[0].recordName == "testItem1")
                XCTAssert(recordIds[1].recordName == "testItem2")
                let record1 = CKRecord(recordType: CloudKitUtils.itemRecordType, recordID: recordIds[0])
                record1["goodName"] = "Test good 1"
                record1["storeName"] = "Test store 1"
                let record2 = CKRecord(recordType: CloudKitUtils.itemRecordType, recordID: recordIds[1])
                record2["goodName"] = "Test good 2"
                record2["storeName"] = "Test store 2"
				operation.perRecordCompletionBlock?(record1, record1.recordID, nil)
				operation.perRecordCompletionBlock?(record2, record2.recordID, nil)
				operation.fetchRecordsCompletionBlock?([:], nil)
			} else {
				fatalError()
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
		XCTAssert(self.operations.localOperations.count == 0)
		XCTAssert(self.operations.sharedOperations.count == 3)
    }
	
	func testFetchChangesSuccessNoTokenNoMore() throws {
		let dbToken = TestServerChangeToken(key: "test")
		let zoneIds = [CKRecordZone.ID(zoneName: "testZone1", ownerName: "testOwner"), CKRecordZone.ID(zoneName: "testZone2", ownerName: "testOwner"), CKRecordZone.ID(zoneName: "testZone3", ownerName: "testOwner")]
        let tokensMap = zoneIds.reduce(into: [CKRecordZone.ID: TestServerChangeToken](), {result, currentZone in
            let token = TestServerChangeToken(key: currentZone.zoneName)!
            result[currentZone] = token
        })
		self.operations.onAddOperation = { operation, localOperations, sharedOperations in
			if localOperations.count == 1 && sharedOperations.count == 0 {
				guard let operation = operation as? CKFetchDatabaseChangesOperation else { fatalError() }
				XCTAssert(operation.previousServerChangeToken == nil)
				for zoneId in zoneIds {
					operation.recordZoneWithIDChangedBlock?(zoneId)
				}
				operation.fetchDatabaseChangesCompletionBlock?(dbToken, false, nil)
			} else if localOperations.count == 2 && sharedOperations.count == 0 {
				guard let operation = operation as? CKFetchRecordZoneChangesOperation else { return }
				let zoneIds = operation.recordZoneIDs ?? []
				XCTAssert(zoneIds[0].zoneName == "testZone1")
				XCTAssert(zoneIds[0].ownerName == "testOwner")
				XCTAssert(zoneIds[1].zoneName == "testZone2")
				XCTAssert(zoneIds[1].ownerName == "testOwner")
				let listRecord1 = CKRecord(recordType: CloudKitUtils.listRecordType, recordID: CKRecord.ID(recordName: "testListRecord1", zoneID: zoneIds[0]))
				let listItem11 = CKRecord(recordType: CloudKitUtils.itemRecordType, recordID: CKRecord.ID(recordName: "testItemRecord11", zoneID: zoneIds[0]))
				let listItem12 = CKRecord(recordType: CloudKitUtils.itemRecordType, recordID: CKRecord.ID(recordName: "testItemRecord12", zoneID: zoneIds[0]))
				listRecord1["name"] = "Test Shopping List"
				listRecord1["date"] = Date(timeIntervalSinceReferenceDate: 602175855.0)
				listRecord1["items"] = [CKRecord.Reference(recordID: listItem11.recordID, action: .none), CKRecord.Reference(recordID: listItem12.recordID, action: .none)]
				listItem11["goodName"] = "Test good 11"
				listItem11["storeName"] = "Test store 11"
				listItem11.parent = CKRecord.Reference(recordID: listRecord1.recordID, action: .none)
				listItem12["goodName"] = "Test good 12"
				listItem12["storeName"] = "Test store 12"
				listItem12.parent = CKRecord.Reference(recordID: listRecord1.recordID, action: .none)
				
				let listRecord2 = CKRecord(recordType: CloudKitUtils.listRecordType, recordID: CKRecord.ID(recordName: "testListRecord2", zoneID: zoneIds[1]))
				let listItem21 = CKRecord(recordType: CloudKitUtils.itemRecordType, recordID: CKRecord.ID(recordName: "testItemRecord21", zoneID: zoneIds[1]))
				let listItem22 = CKRecord(recordType: CloudKitUtils.itemRecordType, recordID: CKRecord.ID(recordName: "testItemRecord22", zoneID: zoneIds[1]))
				listRecord2["name"] = "Test Shopping List 2"
				listRecord2["date"] = Date(timeIntervalSinceReferenceDate: 602175855.0)
				listRecord2["items"] = [CKRecord.Reference(recordID: listItem21.recordID, action: .none), CKRecord.Reference(recordID: listItem22.recordID, action: .none)]
				listItem21["goodName"] = "Test good 21"
				listItem21["storeName"] = "Test store 21"
				listItem21.parent = CKRecord.Reference(recordID: listRecord2.recordID, action: .none)
				listItem22["goodName"] = "Test good 22"
				listItem22["storeName"] = "Test store 22"
				listItem22.parent = CKRecord.Reference(recordID: listRecord2.recordID, action: .none)
				
				for zoneId in zoneIds {
					let option = operation.configurationsByRecordZoneID?[zoneId]
					XCTAssert(option != nil)
					XCTAssert(option?.previousServerChangeToken == nil)
				}
				let records = [listRecord1, listItem11, listItem12, listRecord2, listItem21, listItem22]
				for record in records {
					operation.recordChangedBlock?(record)
				}
				for zoneId in zoneIds {
					operation.recordZoneFetchCompletionBlock?(zoneId, tokensMap[zoneId], nil, false, nil)
				}
				operation.fetchRecordZoneChangesCompletionBlock?(nil)
			} else {
				fatalError()
			}
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
		XCTAssert(self.operations.localOperations.count == 2)
		XCTAssert(self.operations.sharedOperations.count == 0)
		for zoneId in zoneIds {
            XCTAssert((self.storage.getZoneToken(zoneId: zoneId, localDb: true) as? TestServerChangeToken)?.key == zoneId.zoneName)
        }
		XCTAssert((self.storage.getDbToken(localDb: true) as? TestServerChangeToken)?.key == "test")
	}
}
