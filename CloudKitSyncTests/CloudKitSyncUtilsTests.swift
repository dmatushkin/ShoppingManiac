//
//  CloudKitSyncTests.swift
//  CloudKitSyncTests
//
//  Created by Dmitry Matyushkin on 8/14/20.
//  Copyright © 2020 Dmitry Matyushkin. All rights reserved.
//

import XCTest
import CommonError
import DependencyInjection
import CloudKit
@testable import CloudKitSync

//swiftlint:disable type_body_length file_length
class CloudKitSyncUtilsTests: XCTestCase {

	private let operations = CloudKitSyncTestOperations()
    private let storage = CloudKitSyncTestTokenStorage()
    private var utils: CloudKitSyncUtils!

    override func setUp() {
        self.operations.cleanup()
        self.storage.cleanup()
		DIProvider.shared
			.register(forType: CloudKitSyncOperationsProtocol.self, object: self.operations)
			.register(forType: CloudKitSyncTokenStorageProtocol.self, object: self.storage)
        self.utils = CloudKitSyncUtils()
    }

    override func tearDown() {
		DIProvider.shared.clear()
        self.operations.cleanup()
        self.storage.cleanup()
        self.utils = nil
    }

	func testFetchLocalRecordsCombineSuccess() throws {
        let recordIds = [CKRecord.ID(recordName: "aaaa"), CKRecord.ID(recordName: "bbbb"), CKRecord.ID(recordName: "cccc")]
        self.operations.onAddOperation = { operation, localOperations, sharedOperations in
            XCTAssertEqual((operation as? CKFetchRecordsOperation)?.recordIDs?.elementsEqual(recordIds), true)
            for recordId in recordIds {
                let record = CKRecord(recordType: CKRecord.RecordType("testDataRecord"), recordID: recordId)
                (operation as? CKFetchRecordsOperation)?.perRecordCompletionBlock?(record, recordId, nil)
            }
            (operation as? CKFetchRecordsOperation)?.fetchRecordsCompletionBlock?([:], nil)
        }
		let records = try self.utils.fetchRecords(recordIds: recordIds, localDb: true).collect().getValue(test: self, timeout: 10)
        XCTAssertEqual(records.count, 3)
        XCTAssertEqual(records[0].recordID.recordName, "aaaa")
        XCTAssertEqual(records[1].recordID.recordName, "bbbb")
        XCTAssertEqual(records[2].recordID.recordName, "cccc")
    }

	func testFetchLocalRecordsCombineSuccessNoRecords() throws {
		let records = try self.utils.fetchRecords(recordIds: [], localDb: true).collect().getValue(test: self, timeout: 10)
		XCTAssertEqual(records.count, 0)
	}

	func testFetchLocalRecordsCombineRetry() throws {
        let recordIds = [CKRecord.ID(recordName: "aaaa"), CKRecord.ID(recordName: "bbbb"), CKRecord.ID(recordName: "cccc")]
        self.operations.onAddOperation = { operation, localOperations, sharedOperations in
            XCTAssertEqual((operation as? CKFetchRecordsOperation)?.recordIDs?.elementsEqual(recordIds), true)
            if localOperations.count == 1 {
                (operation as? CKFetchRecordsOperation)?.fetchRecordsCompletionBlock?([:], CommonError(description: "retry"))
            } else {
                for recordId in recordIds {
                    let record = CKRecord(recordType: CKRecord.RecordType("testDataRecord"), recordID: recordId)
                    (operation as? CKFetchRecordsOperation)?.perRecordCompletionBlock?(record, recordId, nil)
                }
                (operation as? CKFetchRecordsOperation)?.fetchRecordsCompletionBlock?([:], nil)
            }
        }
        let records = try self.utils.fetchRecords(recordIds: recordIds, localDb: true).collect().getValue(test: self, timeout: 10)
        XCTAssertEqual(self.operations.localOperations.count, 2)
        XCTAssertEqual(records.count, 3)
        XCTAssertEqual(records[0].recordID.recordName, "aaaa")
        XCTAssertEqual(records[1].recordID.recordName, "bbbb")
        XCTAssertEqual(records[2].recordID.recordName, "cccc")
    }

	func testFetchLocalRecordsCombinneFail() {
        let recordIds = [CKRecord.ID(recordName: "aaaa"), CKRecord.ID(recordName: "bbbb"), CKRecord.ID(recordName: "cccc")]
        self.operations.onAddOperation = { operation, localOperations, sharedOperations in
            (operation as? CKFetchRecordsOperation)?.fetchRecordsCompletionBlock?([:], CommonError(description: "fail"))
        }
        do {
            _ = try self.utils.fetchRecords(recordIds: recordIds, localDb: true).collect().getValue(test: self, timeout: 10)
            XCTAssertTrue(false)
        } catch {
            XCTAssertEqual(error.localizedDescription, "fail")
        }
        XCTAssertEqual(self.operations.localOperations.count, 1)
    }

	func testUpdateRecordsCombineSuccess() throws {
        let records = [CKRecord.ID(recordName: "aaaa"), CKRecord.ID(recordName: "bbbb"), CKRecord.ID(recordName: "cccc")].map({CKRecord(recordType: CKRecord.RecordType("testDataRecord"), recordID: $0)})
        self.operations.onAddOperation = { operation, localOperations, sharedOperations in
            guard let operation = operation as? CKModifyRecordsOperation else { return }
            XCTAssertEqual(operation.recordsToSave?.elementsEqual(records), true)
            operation.modifyRecordsCompletionBlock?([], [], nil)
        }
		try self.utils.updateRecords(records: records, localDb: true).wait(test: self, timeout: 10)
        XCTAssertEqual(self.operations.localOperations.count, 1)
    }

	func testUpdateRecordsCombineSuccessNoRecords() throws {
		try self.utils.updateRecords(records: [], localDb: true).wait(test: self, timeout: 10)
        XCTAssertEqual(self.operations.localOperations.count, 0)
    }

	func testUpdateRecordCombineRetry() throws {
        let records = [CKRecord.ID(recordName: "aaaa"), CKRecord.ID(recordName: "bbbb"), CKRecord.ID(recordName: "cccc")].map({CKRecord(recordType: CKRecord.RecordType("testDataRecord"), recordID: $0)})
        self.operations.onAddOperation = { operation, localOperations, sharedOperations in
            guard let operation = operation as? CKModifyRecordsOperation else { return }
            XCTAssertEqual(operation.recordsToSave?.elementsEqual(records), true)
            if localOperations.count == 1 {
                operation.modifyRecordsCompletionBlock?([], [], CommonError(description: "retry"))
            } else {
                operation.modifyRecordsCompletionBlock?([], [], nil)
            }
        }
        try self.utils.updateRecords(records: records, localDb: true).wait(test: self, timeout: 10)
        XCTAssertEqual(self.operations.localOperations.count, 2)
    }

	func testUpdateRecordsCombineFail() {
        let records = [CKRecord.ID(recordName: "aaaa"), CKRecord.ID(recordName: "bbbb"), CKRecord.ID(recordName: "cccc")].map({CKRecord(recordType: CKRecord.RecordType("testDataRecord"), recordID: $0)})
        self.operations.onAddOperation = { operation, localOperations, sharedOperations in
            guard let operation = operation as? CKModifyRecordsOperation else { return }
            XCTAssertEqual(operation.recordsToSave?.elementsEqual(records), true)
            operation.modifyRecordsCompletionBlock?([], [], CommonError(description: "fail"))
        }
        do {
            try self.utils.updateRecords(records: records, localDb: true).wait(test: self, timeout: 10)
            XCTAssertTrue(false)
        } catch {
            XCTAssertEqual(error.localizedDescription, "fail")
        }
        XCTAssertEqual(self.operations.localOperations.count, 1)
    }

	func testFetchDatabaseChangesSuccessCombineNoTokenNoMoreComing() throws {
        let zoneIds = [CKRecordZone.ID(zoneName: "testZone1", ownerName: "testOwner"), CKRecordZone.ID(zoneName: "testZone2", ownerName: "testOwner"), CKRecordZone.ID(zoneName: "testZone3", ownerName: "testOwner")]
        let token = TestServerChangeToken(key: "test")
        self.operations.onAddOperation = { operation, localOperations, sharedOperations in
            guard let operation = operation as? CKFetchDatabaseChangesOperation else { return }
            XCTAssertEqual(operation.previousServerChangeToken, nil)
            for zoneId in zoneIds {
                operation.recordZoneWithIDChangedBlock?(zoneId)
            }
            operation.fetchDatabaseChangesCompletionBlock?(token, false, nil)
        }
        let zoneIdsResult = try self.utils.fetchDatabaseChanges(localDb: true).getValue(test: self, timeout: 10)
        XCTAssertEqual(self.operations.localOperations.count, 1)
        XCTAssertEqual(zoneIdsResult.elementsEqual(zoneIds), true)
        XCTAssertEqual((self.storage.getDbToken(localDb: true) as? TestServerChangeToken)?.key, "test")
    }

	func testFetchDatabaseChangesSuccessCombineHasTokenNoMoreComing() throws {
        let zoneIds = [CKRecordZone.ID(zoneName: "testZone1", ownerName: "testOwner"), CKRecordZone.ID(zoneName: "testZone2", ownerName: "testOwner"), CKRecordZone.ID(zoneName: "testZone3", ownerName: "testOwner")]
        self.storage.setDbToken(localDb: true, token: TestServerChangeToken(key: "orig"))
        let token = TestServerChangeToken(key: "test")
        self.operations.onAddOperation = { operation, localOperations, sharedOperations in
            guard let operation = operation as? CKFetchDatabaseChangesOperation else { return }
            XCTAssertNotEqual((operation.previousServerChangeToken as? TestServerChangeToken), nil)
            for zoneId in zoneIds {
                operation.recordZoneWithIDChangedBlock?(zoneId)
            }
            operation.fetchDatabaseChangesCompletionBlock?(token, false, nil)
        }
        let zoneIdsResult = try self.utils.fetchDatabaseChanges(localDb: true).getValue(test: self, timeout: 10)
        XCTAssertEqual(self.operations.localOperations.count, 1)
        XCTAssertEqual(zoneIdsResult.elementsEqual(zoneIds), true)
        XCTAssertEqual((self.storage.getDbToken(localDb: true) as? TestServerChangeToken)?.key, "test")
    }

	func testFetchDatabaseChangesSuccessCombineNoTokenHasMoreComing() throws {
        let zoneIds = [CKRecordZone.ID(zoneName: "testZone1", ownerName: "testOwner"), CKRecordZone.ID(zoneName: "testZone2", ownerName: "testOwner"), CKRecordZone.ID(zoneName: "testZone3", ownerName: "testOwner")]
        let zoneIds2 = [CKRecordZone.ID(zoneName: "testZone4", ownerName: "testOwner"), CKRecordZone.ID(zoneName: "testZone5", ownerName: "testOwner"), CKRecordZone.ID(zoneName: "testZone6", ownerName: "testOwner")]
        let token = TestServerChangeToken(key: "test")
        let token2 = TestServerChangeToken(key: "test2")
        self.operations.onAddOperation = { operation, localOperations, sharedOperations in
            guard let operation = operation as? CKFetchDatabaseChangesOperation else { return }
            if localOperations.count == 1 {
                XCTAssertEqual(operation.previousServerChangeToken, nil)
                for zoneId in zoneIds {
                    operation.recordZoneWithIDChangedBlock?(zoneId)
                }
                operation.fetchDatabaseChangesCompletionBlock?(token, true, nil)
            } else {
                XCTAssertNotEqual(operation.previousServerChangeToken, nil)
                for zoneId in zoneIds2 {
                    operation.recordZoneWithIDChangedBlock?(zoneId)
                }
                operation.fetchDatabaseChangesCompletionBlock?(token2, false, nil)
            }
        }
        let zoneIdsResult = try self.utils.fetchDatabaseChanges(localDb: true).getValue(test: self, timeout: 10)
        XCTAssertEqual(self.operations.localOperations.count, 2)
        XCTAssertEqual(zoneIdsResult.elementsEqual(zoneIds + zoneIds2), true)
        XCTAssertEqual((self.storage.getDbToken(localDb: true) as? TestServerChangeToken)?.key, "test2")
    }

	func testFetchDatabaseChangesCombineRetry() throws {
        let zoneIds = [CKRecordZone.ID(zoneName: "testZone1", ownerName: "testOwner"), CKRecordZone.ID(zoneName: "testZone2", ownerName: "testOwner"), CKRecordZone.ID(zoneName: "testZone3", ownerName: "testOwner")]
        let token = TestServerChangeToken(key: "test")
        self.operations.onAddOperation = { operation, localOperations, sharedOperations in
            guard let operation = operation as? CKFetchDatabaseChangesOperation else { return }
            if localOperations.count == 1 {
                XCTAssertEqual(operation.previousServerChangeToken, nil)
                operation.fetchDatabaseChangesCompletionBlock?(nil, false, CommonError(description: "retry"))
            } else {
                XCTAssertEqual(operation.previousServerChangeToken, nil)
                for zoneId in zoneIds {
                    operation.recordZoneWithIDChangedBlock?(zoneId)
                }
                operation.fetchDatabaseChangesCompletionBlock?(token, false, nil)
            }
        }
        let zoneIdsResult = try self.utils.fetchDatabaseChanges(localDb: true).getValue(test: self, timeout: 10)
        XCTAssertEqual(self.operations.localOperations.count, 2)
        XCTAssertEqual(zoneIdsResult.elementsEqual(zoneIds), true)
        XCTAssertEqual((self.storage.getDbToken(localDb: true) as? TestServerChangeToken)?.key, "test")
    }

	func testFetchDatabaseChangesCombineTokenReset() throws {
        let zoneIds = [CKRecordZone.ID(zoneName: "testZone1", ownerName: "testOwner"), CKRecordZone.ID(zoneName: "testZone2", ownerName: "testOwner"), CKRecordZone.ID(zoneName: "testZone3", ownerName: "testOwner")]
        let token = TestServerChangeToken(key: "test")
        self.storage.setDbToken(localDb: true, token: TestServerChangeToken(key: "orig"))
        self.operations.onAddOperation = { operation, localOperations, sharedOperations in
            guard let operation = operation as? CKFetchDatabaseChangesOperation else { return }
            if localOperations.count == 1 {
                XCTAssertNotEqual(operation.previousServerChangeToken, nil)
                operation.fetchDatabaseChangesCompletionBlock?(nil, false, CommonError(description: "token"))
            } else {
                XCTAssertEqual(operation.previousServerChangeToken, nil)
                for zoneId in zoneIds {
                    operation.recordZoneWithIDChangedBlock?(zoneId)
                }
                operation.fetchDatabaseChangesCompletionBlock?(token, false, nil)
            }
        }
        let zoneIdsResult = try self.utils.fetchDatabaseChanges(localDb: true).getValue(test: self, timeout: 10)
        XCTAssertEqual(self.operations.localOperations.count, 2)
        XCTAssertEqual(zoneIdsResult.elementsEqual(zoneIds), true)
        XCTAssertEqual((self.storage.getDbToken(localDb: true) as? TestServerChangeToken)?.key, "test")
    }

	func testFetchDatabaseChangesCombineFail() {
        self.operations.onAddOperation = { operation, localOperations, sharedOperations in
            guard let operation = operation as? CKFetchDatabaseChangesOperation else { return }
            operation.fetchDatabaseChangesCompletionBlock?(nil, false, CommonError(description: "fail"))
        }
        do {
            _ = try self.utils.fetchDatabaseChanges(localDb: true).getValue(test: self, timeout: 10)
            XCTAssertTrue(false)
        } catch {
            XCTAssertEqual(error.localizedDescription, "fail")
        }
        XCTAssertEqual(self.operations.localOperations.count, 1)
    }

	func testFetchDatabaseChangesCombineNoTokenError() {
        self.operations.onAddOperation = { operation, localOperations, sharedOperations in
            guard let operation = operation as? CKFetchDatabaseChangesOperation else { return }
            operation.fetchDatabaseChangesCompletionBlock?(nil, false, nil)
        }
        do {
            _ = try self.utils.fetchDatabaseChanges(localDb: true).getValue(test: self, timeout: 10)
            XCTAssertTrue(false)
        } catch {
            XCTAssertEqual(error.localizedDescription, "iCloud token is empty")
        }
        XCTAssertEqual(self.operations.localOperations.count, 1)
    }

	func testFetchZoneChangesCombineSuccessNoTokenNoMore() throws {
        let zoneIds = [CKRecordZone.ID(zoneName: "testZone1", ownerName: "testOwner"), CKRecordZone.ID(zoneName: "testZone2", ownerName: "testOwner"), CKRecordZone.ID(zoneName: "testZone3", ownerName: "testOwner")]
        let tokensMap = zoneIds.reduce(into: [CKRecordZone.ID: TestServerChangeToken](), {result, currentZone in
            let token = TestServerChangeToken(key: currentZone.zoneName)!
            result[currentZone] = token
        })
        let records = [CKRecord.ID(recordName: "aaa"), CKRecord.ID(recordName: "bbb"), CKRecord.ID(recordName: "ccc"), CKRecord.ID(recordName: "ddd")].map({CKRecord(recordType: CKRecord.RecordType("testRecordType"), recordID: $0)})
        self.operations.onAddOperation = { operation, localOperations, sharedOperations in
            guard let operation = operation as? CKFetchRecordZoneChangesOperation else { return }
            for zoneId in zoneIds {
                let option = operation.configurationsByRecordZoneID?[zoneId]
                XCTAssertNotEqual(option, nil)
                XCTAssertEqual(option?.previousServerChangeToken, nil)
            }
            for record in records {
                operation.recordChangedBlock?(record)
            }
            for zoneId in zoneIds {
                operation.recordZoneFetchCompletionBlock?(zoneId, tokensMap[zoneId], nil, false, nil)
            }
            operation.fetchRecordZoneChangesCompletionBlock?(nil)
        }
		let resultRecords = try self.utils.fetchZoneChanges(zoneIds: zoneIds, localDb: true).getValue(test: self, timeout: 10)
        XCTAssertEqual(self.operations.localOperations.count, 1)
        XCTAssertTrue(resultRecords.elementsEqual(records))
        for zoneId in zoneIds {
            XCTAssertEqual((self.storage.getZoneToken(zoneId: zoneId, localDb: true) as? TestServerChangeToken)?.key, zoneId.zoneName)
        }
    }

	func testFetchZoneChangesCombineSuccessNoZones() throws {
		let resultRecords = try self.utils.fetchZoneChanges(zoneIds: [], localDb: true).getValue(test: self, timeout: 10)
        XCTAssertEqual(self.operations.localOperations.count, 0)
        XCTAssertEqual(resultRecords.count, 0)
    }

	func testFetchZoneChangesCombineSuccessHasTokenNoMore() throws {
        let zoneIds = [CKRecordZone.ID(zoneName: "testZone1", ownerName: "testOwner"), CKRecordZone.ID(zoneName: "testZone2", ownerName: "testOwner"), CKRecordZone.ID(zoneName: "testZone3", ownerName: "testOwner")]
        for zoneId in zoneIds {
            let token = TestServerChangeToken(key: zoneId.zoneName + "prev")!
            self.storage.setZoneToken(zoneId: zoneId, localDb: true, token: token)
        }
        let tokensMap = zoneIds.reduce(into: [CKRecordZone.ID: TestServerChangeToken](), {result, currentZone in
            let token = TestServerChangeToken(key: currentZone.zoneName)!
            result[currentZone] = token
        })
        let records = [CKRecord.ID(recordName: "aaa"), CKRecord.ID(recordName: "bbb"), CKRecord.ID(recordName: "ccc"), CKRecord.ID(recordName: "ddd")].map({CKRecord(recordType: CKRecord.RecordType("testRecordType"), recordID: $0)})
        self.operations.onAddOperation = { operation, localOperations, sharedOperations in
            guard let operation = operation as? CKFetchRecordZoneChangesOperation else { return }
            for zoneId in zoneIds {
                let option = operation.configurationsByRecordZoneID?[zoneId]
                XCTAssertNotEqual(option, nil)
                XCTAssertNotEqual(option?.previousServerChangeToken, nil)
            }
            for record in records {
                operation.recordChangedBlock?(record)
            }
            for zoneId in zoneIds {
                operation.recordZoneFetchCompletionBlock?(zoneId, tokensMap[zoneId], nil, false, nil)
            }
            operation.fetchRecordZoneChangesCompletionBlock?(nil)
        }
        let resultRecords = try self.utils.fetchZoneChanges(zoneIds: zoneIds, localDb: true).getValue(test: self, timeout: 10)
        XCTAssertEqual(self.operations.localOperations.count, 1)
        XCTAssertTrue(resultRecords.elementsEqual(records))
        for zoneId in zoneIds {
            XCTAssertEqual((self.storage.getZoneToken(zoneId: zoneId, localDb: true) as? TestServerChangeToken)?.key, zoneId.zoneName)
        }
    }

	func testFetchZoneChangesCombineSuccessNoTokenHasMore() throws {
        let zoneIds = [CKRecordZone.ID(zoneName: "testZone1", ownerName: "testOwner"), CKRecordZone.ID(zoneName: "testZone2", ownerName: "testOwner"), CKRecordZone.ID(zoneName: "testZone3", ownerName: "testOwner")]
        let tokensMap = zoneIds.reduce(into: [CKRecordZone.ID: TestServerChangeToken](), {result, currentZone in
            let token = TestServerChangeToken(key: currentZone.zoneName)!
            result[currentZone] = token
        })
        let tokensMap2 = zoneIds.reduce(into: [CKRecordZone.ID: TestServerChangeToken](), {result, currentZone in
            let token = TestServerChangeToken(key: currentZone.zoneName + "2")!
            result[currentZone] = token
        })
        let records = [CKRecord.ID(recordName: "aaa"), CKRecord.ID(recordName: "bbb"), CKRecord.ID(recordName: "ccc"), CKRecord.ID(recordName: "ddd")].map({CKRecord(recordType: CKRecord.RecordType("testRecordType"), recordID: $0)})
        let records2 = [CKRecord.ID(recordName: "eee"), CKRecord.ID(recordName: "fff"), CKRecord.ID(recordName: "ggg"), CKRecord.ID(recordName: "hhh")].map({CKRecord(recordType: CKRecord.RecordType("testRecordType"), recordID: $0)})
        self.operations.onAddOperation = { operation, localOperations, sharedOperations in
            guard let operation = operation as? CKFetchRecordZoneChangesOperation else { return }
            if localOperations.count == 1 {
                for zoneId in zoneIds {
                    let option = operation.configurationsByRecordZoneID?[zoneId]
                    XCTAssertNotEqual(option, nil)
                    XCTAssertEqual(option?.previousServerChangeToken, nil)
                }
                for record in records {
                    operation.recordChangedBlock?(record)
                }
                for zoneId in zoneIds {
                    operation.recordZoneFetchCompletionBlock?(zoneId, tokensMap[zoneId], nil, true, nil)
                }
                operation.fetchRecordZoneChangesCompletionBlock?(nil)
            } else {
                for zoneId in zoneIds {
                    let option = operation.configurationsByRecordZoneID?[zoneId]
                    XCTAssertNotEqual(option, nil)
                    XCTAssertNotEqual(option?.previousServerChangeToken, nil)
                }
                for record in records2 {
                    operation.recordChangedBlock?(record)
                }
                for zoneId in zoneIds {
                    operation.recordZoneFetchCompletionBlock?(zoneId, tokensMap2[zoneId], nil, false, nil)
                }
                operation.fetchRecordZoneChangesCompletionBlock?(nil)
            }
        }
        let resultRecords = try self.utils.fetchZoneChanges(zoneIds: zoneIds, localDb: true).getValue(test: self, timeout: 10)
        XCTAssertEqual(self.operations.localOperations.count, 2)
        XCTAssertTrue(resultRecords.elementsEqual(records + records2))
        for zoneId in zoneIds {
            XCTAssertEqual((self.storage.getZoneToken(zoneId: zoneId, localDb: true) as? TestServerChangeToken)?.key, (zoneId.zoneName + "2"))
        }
    }

	func testFetchZoneChangesCombineSuccessResetToken() throws {
        let zoneIds = [CKRecordZone.ID(zoneName: "testZone1", ownerName: "testOwner"), CKRecordZone.ID(zoneName: "testZone2", ownerName: "testOwner"), CKRecordZone.ID(zoneName: "testZone3", ownerName: "testOwner")]
        let tokensMap = zoneIds.reduce(into: [CKRecordZone.ID: TestServerChangeToken](), {result, currentZone in
            let token = TestServerChangeToken(key: currentZone.zoneName)!
            result[currentZone] = token
        })
        for zoneId in zoneIds {
            let token = TestServerChangeToken(key: zoneId.zoneName + "prev")!
            self.storage.setZoneToken(zoneId: zoneId, localDb: true, token: token)
        }
        let records = [CKRecord.ID(recordName: "aaa"), CKRecord.ID(recordName: "bbb"), CKRecord.ID(recordName: "ccc"), CKRecord.ID(recordName: "ddd")].map({CKRecord(recordType: CKRecord.RecordType("testRecordType"), recordID: $0)})
        self.operations.onAddOperation = { operation, localOperations, sharedOperations in
            guard let operation = operation as? CKFetchRecordZoneChangesOperation else { return }
            if localOperations.count == 1 {
                for zoneId in zoneIds {
                    let option = operation.configurationsByRecordZoneID?[zoneId]
                    XCTAssertNotEqual(option, nil)
                    XCTAssertNotEqual(option?.previousServerChangeToken, nil)
                }
                for zoneId in zoneIds {
                    operation.recordZoneFetchCompletionBlock?(zoneId, tokensMap[zoneId], nil, true, CommonError(description: "token"))
                }
                operation.fetchRecordZoneChangesCompletionBlock?(CommonError(description: "token"))
            } else {
                for zoneId in zoneIds {
                    let option = operation.configurationsByRecordZoneID?[zoneId]
                    XCTAssertNotEqual(option, nil)
                    XCTAssertEqual(option?.previousServerChangeToken, nil)
                }
                for record in records {
                    operation.recordChangedBlock?(record)
                }
                for zoneId in zoneIds {
                    operation.recordZoneFetchCompletionBlock?(zoneId, tokensMap[zoneId], nil, false, nil)
                }
                operation.fetchRecordZoneChangesCompletionBlock?(nil)
            }
        }
        let resultRecords = try self.utils.fetchZoneChanges(zoneIds: zoneIds, localDb: true).getValue(test: self, timeout: 10)
        XCTAssertEqual(self.operations.localOperations.count, 2)
        XCTAssertTrue(resultRecords.elementsEqual(records))
        for zoneId in zoneIds {
            XCTAssertEqual((self.storage.getZoneToken(zoneId: zoneId, localDb: true) as? TestServerChangeToken)?.key, (zoneId.zoneName))
        }
    }

	func testFetchZoneChangesCombineSuccessRetry() throws {
        let zoneIds = [CKRecordZone.ID(zoneName: "testZone1", ownerName: "testOwner"), CKRecordZone.ID(zoneName: "testZone2", ownerName: "testOwner"), CKRecordZone.ID(zoneName: "testZone3", ownerName: "testOwner")]
        let tokensMap = zoneIds.reduce(into: [CKRecordZone.ID: TestServerChangeToken](), {result, currentZone in
            let token = TestServerChangeToken(key: currentZone.zoneName)!
            result[currentZone] = token
        })
        let records = [CKRecord.ID(recordName: "aaa"), CKRecord.ID(recordName: "bbb"), CKRecord.ID(recordName: "ccc"), CKRecord.ID(recordName: "ddd")].map({CKRecord(recordType: CKRecord.RecordType("testRecordType"), recordID: $0)})
        self.operations.onAddOperation = { operation, localOperations, sharedOperations in
            guard let operation = operation as? CKFetchRecordZoneChangesOperation else { return }
            if localOperations.count == 1 {
                for zoneId in zoneIds {
                    let option = operation.configurationsByRecordZoneID?[zoneId]
                    XCTAssertNotEqual(option, nil)
                    XCTAssertEqual(option?.previousServerChangeToken, nil)
                }
                for zoneId in zoneIds {
                    operation.recordZoneFetchCompletionBlock?(zoneId, tokensMap[zoneId], nil, true, CommonError(description: "retry"))
                }
                operation.fetchRecordZoneChangesCompletionBlock?(CommonError(description: "retry"))
            } else {
                for zoneId in zoneIds {
                    let option = operation.configurationsByRecordZoneID?[zoneId]
                    XCTAssertNotEqual(option, nil)
                    XCTAssertEqual(option?.previousServerChangeToken, nil)
                }
                for record in records {
                    operation.recordChangedBlock?(record)
                }
                for zoneId in zoneIds {
                    operation.recordZoneFetchCompletionBlock?(zoneId, tokensMap[zoneId], nil, false, nil)
                }
                operation.fetchRecordZoneChangesCompletionBlock?(nil)
            }
        }
        let resultRecords = try self.utils.fetchZoneChanges(zoneIds: zoneIds, localDb: true).getValue(test: self, timeout: 10)
        XCTAssertEqual(self.operations.localOperations.count, 2)
        XCTAssertTrue(resultRecords.elementsEqual(records))
        for zoneId in zoneIds {
            XCTAssertEqual((self.storage.getZoneToken(zoneId: zoneId, localDb: true) as? TestServerChangeToken)?.key, (zoneId.zoneName))
        }
    }

	func testFetchZoneChangesCombineFail() {
        let zoneIds = [CKRecordZone.ID(zoneName: "testZone1", ownerName: "testOwner"), CKRecordZone.ID(zoneName: "testZone2", ownerName: "testOwner"), CKRecordZone.ID(zoneName: "testZone3", ownerName: "testOwner")]
        self.operations.onAddOperation = { operation, localOperations, sharedOperations in
            guard let operation = operation as? CKFetchRecordZoneChangesOperation else { return }
            operation.fetchRecordZoneChangesCompletionBlock?(CommonError(description: "fail"))
        }
        do {
			_ = try self.utils.fetchZoneChanges(zoneIds: zoneIds, localDb: true).getValue(test: self, timeout: 10)
            XCTAssertTrue(false)
        } catch {
            XCTAssertEqual(error.localizedDescription, "fail")
        }
        XCTAssertEqual(self.operations.localOperations.count, 1)
    }
}
