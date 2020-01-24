//
//  CloudKitUtilsTests.swift
//  ShoppingManiacUnitTests
//
//  Created by Dmitry Matyushkin on 1/24/20.
//  Copyright © 2020 Dmitry Matyushkin. All rights reserved.
//

import XCTest
import CloudKit
import RxBlocking

//swiftlint:disable type_body_length file_length
class CloudKitUtilsTests: XCTestCase {
    
    private let operations = CloudKitTestOperations()
    private let storage = CloudKitTestTokenStorage()
    private var utils: CloudKitUtils!

    override func setUp() {
        self.operations.cleanup()
        self.storage.cleanup()
        self.utils = CloudKitUtils(operations: self.operations, storage: self.storage)
    }

    override func tearDown() {
        self.operations.cleanup()
        self.storage.cleanup()
        self.utils = nil
    }

    func testFetchLocalRecordsSuccess() throws {
        let recordIds = [CKRecord.ID(recordName: "aaaa"), CKRecord.ID(recordName: "bbbb"), CKRecord.ID(recordName: "cccc")]
        self.operations.onAddOperation = { operation, localOperations, sharedOperations in
            XCTAssert((operation as? CKFetchRecordsOperation)?.recordIDs?.elementsEqual(recordIds) == true)
            for recordId in recordIds {
                let record = CKRecord(recordType: CKRecord.RecordType("testDataRecord"), recordID: recordId)
                (operation as? CKFetchRecordsOperation)?.perRecordCompletionBlock?(record, recordId, nil)
            }
            (operation as? CKFetchRecordsOperation)?.fetchRecordsCompletionBlock?([:], nil)
        }
        let records = try self.utils.fetchRecords(recordIds: recordIds, localDb: true).toBlocking().toArray()
        XCTAssert(records.count == 3)
        XCTAssert(records[0].recordID.recordName == "aaaa")
        XCTAssert(records[1].recordID.recordName == "bbbb")
        XCTAssert(records[2].recordID.recordName == "cccc")
    }
    
    func testFetchLocalRecordsRetry() throws {
        let recordIds = [CKRecord.ID(recordName: "aaaa"), CKRecord.ID(recordName: "bbbb"), CKRecord.ID(recordName: "cccc")]
        self.operations.onAddOperation = { operation, localOperations, sharedOperations in
            XCTAssert((operation as? CKFetchRecordsOperation)?.recordIDs?.elementsEqual(recordIds) == true)
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
        let records = try self.utils.fetchRecords(recordIds: recordIds, localDb: true).toBlocking().toArray()
        XCTAssert(self.operations.localOperations.count == 2)
        XCTAssert(records.count == 3)
        XCTAssert(records[0].recordID.recordName == "aaaa")
        XCTAssert(records[1].recordID.recordName == "bbbb")
        XCTAssert(records[2].recordID.recordName == "cccc")
    }
    
    func testFetchLocalRecordsFail() {
        let recordIds = [CKRecord.ID(recordName: "aaaa"), CKRecord.ID(recordName: "bbbb"), CKRecord.ID(recordName: "cccc")]
        self.operations.onAddOperation = { operation, localOperations, sharedOperations in
            (operation as? CKFetchRecordsOperation)?.fetchRecordsCompletionBlock?([:], CommonError(description: "fail"))
        }
        do {
            _ = try self.utils.fetchRecords(recordIds: recordIds, localDb: true).toBlocking().toArray()
            XCTAssert(false)
        } catch {
            XCTAssert(error.localizedDescription == "fail")
        }
        XCTAssert(self.operations.localOperations.count == 1)
    }
    
    func testUpdateRecordsSuccess() throws {
        let records = [CKRecord.ID(recordName: "aaaa"), CKRecord.ID(recordName: "bbbb"), CKRecord.ID(recordName: "cccc")].map({CKRecord(recordType: CKRecord.RecordType("testDataRecord"), recordID: $0)})
        self.operations.onAddOperation = { operation, localOperations, sharedOperations in
            guard let operation = operation as? CKModifyRecordsOperation else { return }
            XCTAssert(operation.recordsToSave?.elementsEqual(records) == true)
            operation.modifyRecordsCompletionBlock?([], [], nil)
        }
        _ = try self.utils.updateRecords(records: records, localDb: true).toBlocking().first()
        XCTAssert(self.operations.localOperations.count == 1)
    }
    
    func testUpdateRecordRetry() throws {
        let records = [CKRecord.ID(recordName: "aaaa"), CKRecord.ID(recordName: "bbbb"), CKRecord.ID(recordName: "cccc")].map({CKRecord(recordType: CKRecord.RecordType("testDataRecord"), recordID: $0)})
        self.operations.onAddOperation = { operation, localOperations, sharedOperations in
            guard let operation = operation as? CKModifyRecordsOperation else { return }
            XCTAssert(operation.recordsToSave?.elementsEqual(records) == true)
            if localOperations.count == 1 {
                operation.modifyRecordsCompletionBlock?([], [], CommonError(description: "retry"))
            } else {
                operation.modifyRecordsCompletionBlock?([], [], nil)
            }
        }
        _ = try self.utils.updateRecords(records: records, localDb: true).toBlocking().first()
        XCTAssert(self.operations.localOperations.count == 2)
    }
    
    func testUpdateRecordsFail() {
        let records = [CKRecord.ID(recordName: "aaaa"), CKRecord.ID(recordName: "bbbb"), CKRecord.ID(recordName: "cccc")].map({CKRecord(recordType: CKRecord.RecordType("testDataRecord"), recordID: $0)})
        self.operations.onAddOperation = { operation, localOperations, sharedOperations in
            guard let operation = operation as? CKModifyRecordsOperation else { return }
            XCTAssert(operation.recordsToSave?.elementsEqual(records) == true)
            operation.modifyRecordsCompletionBlock?([], [], CommonError(description: "fail"))
        }
        do {
            _ = try self.utils.updateRecords(records: records, localDb: true).toBlocking().first()
            XCTAssert(false)
        } catch {
            XCTAssert(error.localizedDescription == "fail")
        }
        XCTAssert(self.operations.localOperations.count == 1)
    }
    
    func testFetchDatabaseChangesSuccessNoTokenNoMoreComing() throws {
        let zoneIds = [CKRecordZone.ID(zoneName: "testZone1", ownerName: "testOwner"), CKRecordZone.ID(zoneName: "testZone2", ownerName: "testOwner"), CKRecordZone.ID(zoneName: "testZone3", ownerName: "testOwner")]
        let token = TestServerChangeToken(key: "test")
        self.operations.onAddOperation = { operation, localOperations, sharedOperations in
            guard let operation = operation as? CKFetchDatabaseChangesOperation else { return }
            XCTAssert(operation.previousServerChangeToken == nil)
            for zoneId in zoneIds {
                operation.recordZoneWithIDChangedBlock?(zoneId)
            }
            operation.fetchDatabaseChangesCompletionBlock?(token, false, nil)
        }
        let wrapper = try self.utils.fetchDatabaseChanges(localDb: true).toBlocking().first()
        XCTAssert(self.operations.localOperations.count == 1)
        XCTAssert(wrapper?.localDb == true)
        XCTAssert(wrapper?.zoneIds.elementsEqual(zoneIds) == true)
        XCTAssert((self.storage.getDbToken(localDb: true) as? TestServerChangeToken)?.key == "test")
    }
    
    func testFetchDatabaseChangesSuccessHasTokenNoMoreComing() throws {
        let zoneIds = [CKRecordZone.ID(zoneName: "testZone1", ownerName: "testOwner"), CKRecordZone.ID(zoneName: "testZone2", ownerName: "testOwner"), CKRecordZone.ID(zoneName: "testZone3", ownerName: "testOwner")]
        self.storage.setDbToken(localDb: true, token: TestServerChangeToken(key: "orig"))
        let token = TestServerChangeToken(key: "test")
        self.operations.onAddOperation = { operation, localOperations, sharedOperations in
            guard let operation = operation as? CKFetchDatabaseChangesOperation else { return }
            XCTAssert((operation.previousServerChangeToken as? TestServerChangeToken) != nil)
            for zoneId in zoneIds {
                operation.recordZoneWithIDChangedBlock?(zoneId)
            }
            operation.fetchDatabaseChangesCompletionBlock?(token, false, nil)
        }
        let wrapper = try self.utils.fetchDatabaseChanges(localDb: true).toBlocking().first()
        XCTAssert(self.operations.localOperations.count == 1)
        XCTAssert(wrapper?.localDb == true)
        XCTAssert(wrapper?.zoneIds.elementsEqual(zoneIds) == true)
        XCTAssert((self.storage.getDbToken(localDb: true) as? TestServerChangeToken)?.key == "test")
    }
    
    func testFetchDatabaseChangesSuccessNoTokenHasMoreComing() throws {
        let zoneIds = [CKRecordZone.ID(zoneName: "testZone1", ownerName: "testOwner"), CKRecordZone.ID(zoneName: "testZone2", ownerName: "testOwner"), CKRecordZone.ID(zoneName: "testZone3", ownerName: "testOwner")]
        let zoneIds2 = [CKRecordZone.ID(zoneName: "testZone4", ownerName: "testOwner"), CKRecordZone.ID(zoneName: "testZone5", ownerName: "testOwner"), CKRecordZone.ID(zoneName: "testZone6", ownerName: "testOwner")]
        let token = TestServerChangeToken(key: "test")
        let token2 = TestServerChangeToken(key: "test2")
        self.operations.onAddOperation = { operation, localOperations, sharedOperations in
            guard let operation = operation as? CKFetchDatabaseChangesOperation else { return }
            if localOperations.count == 1 {
                XCTAssert(operation.previousServerChangeToken == nil)
                for zoneId in zoneIds {
                    operation.recordZoneWithIDChangedBlock?(zoneId)
                }
                operation.fetchDatabaseChangesCompletionBlock?(token, true, nil)
            } else {
                XCTAssert(operation.previousServerChangeToken != nil)
                for zoneId in zoneIds2 {
                    operation.recordZoneWithIDChangedBlock?(zoneId)
                }
                operation.fetchDatabaseChangesCompletionBlock?(token2, false, nil)
            }
        }
        let wrapper = try self.utils.fetchDatabaseChanges(localDb: true).toBlocking().first()
        XCTAssert(self.operations.localOperations.count == 2)
        XCTAssert(wrapper?.localDb == true)
        XCTAssert(wrapper?.zoneIds.elementsEqual(zoneIds + zoneIds2) == true)
        XCTAssert((self.storage.getDbToken(localDb: true) as? TestServerChangeToken)?.key == "test2")
    }
    
    func testFetchDatabaseChangesRetry() throws {
        let zoneIds = [CKRecordZone.ID(zoneName: "testZone1", ownerName: "testOwner"), CKRecordZone.ID(zoneName: "testZone2", ownerName: "testOwner"), CKRecordZone.ID(zoneName: "testZone3", ownerName: "testOwner")]
        let token = TestServerChangeToken(key: "test")
        self.operations.onAddOperation = { operation, localOperations, sharedOperations in
            guard let operation = operation as? CKFetchDatabaseChangesOperation else { return }
            if localOperations.count == 1 {
                XCTAssert(operation.previousServerChangeToken == nil)
                operation.fetchDatabaseChangesCompletionBlock?(nil, false, CommonError(description: "retry"))
            } else {
                XCTAssert(operation.previousServerChangeToken == nil)
                for zoneId in zoneIds {
                    operation.recordZoneWithIDChangedBlock?(zoneId)
                }
                operation.fetchDatabaseChangesCompletionBlock?(token, false, nil)
            }
        }
        let wrapper = try self.utils.fetchDatabaseChanges(localDb: true).toBlocking().first()
        XCTAssert(self.operations.localOperations.count == 2)
        XCTAssert(wrapper?.localDb == true)
        XCTAssert(wrapper?.zoneIds.elementsEqual(zoneIds) == true)
        XCTAssert((self.storage.getDbToken(localDb: true) as? TestServerChangeToken)?.key == "test")
    }
    
    func testFetchDatabaseChangesTokenReset() throws {
        let zoneIds = [CKRecordZone.ID(zoneName: "testZone1", ownerName: "testOwner"), CKRecordZone.ID(zoneName: "testZone2", ownerName: "testOwner"), CKRecordZone.ID(zoneName: "testZone3", ownerName: "testOwner")]
        let token = TestServerChangeToken(key: "test")
        self.storage.setDbToken(localDb: true, token: TestServerChangeToken(key: "orig"))
        self.operations.onAddOperation = { operation, localOperations, sharedOperations in
            guard let operation = operation as? CKFetchDatabaseChangesOperation else { return }
            if localOperations.count == 1 {
                XCTAssert(operation.previousServerChangeToken != nil)
                operation.fetchDatabaseChangesCompletionBlock?(nil, false, CommonError(description: "token"))
            } else {
                XCTAssert(operation.previousServerChangeToken == nil)
                for zoneId in zoneIds {
                    operation.recordZoneWithIDChangedBlock?(zoneId)
                }
                operation.fetchDatabaseChangesCompletionBlock?(token, false, nil)
            }
        }
        let wrapper = try self.utils.fetchDatabaseChanges(localDb: true).toBlocking().first()
        XCTAssert(self.operations.localOperations.count == 2)
        XCTAssert(wrapper?.localDb == true)
        XCTAssert(wrapper?.zoneIds.elementsEqual(zoneIds) == true)
        XCTAssert((self.storage.getDbToken(localDb: true) as? TestServerChangeToken)?.key == "test")
    }
    
    func testFetchDatabaseChangesFail() {
        self.operations.onAddOperation = { operation, localOperations, sharedOperations in
            guard let operation = operation as? CKFetchDatabaseChangesOperation else { return }
            operation.fetchDatabaseChangesCompletionBlock?(nil, false, CommonError(description: "fail"))
        }
        do {
            _ = try self.utils.fetchDatabaseChanges(localDb: true).toBlocking().first()
            XCTAssert(false)
        } catch {
            XCTAssert(error.localizedDescription == "fail")
        }
        XCTAssert(self.operations.localOperations.count == 1)
    }
    
    func testFetchDatabaseChangesNoTokenError() {
        self.operations.onAddOperation = { operation, localOperations, sharedOperations in
            guard let operation = operation as? CKFetchDatabaseChangesOperation else { return }
            operation.fetchDatabaseChangesCompletionBlock?(nil, false, nil)
        }
        do {
            _ = try self.utils.fetchDatabaseChanges(localDb: true).toBlocking().first()
            XCTAssert(false)
        } catch {
            XCTAssert(error.localizedDescription == "iCloud token is empty")
        }
        XCTAssert(self.operations.localOperations.count == 1)
    }
    
    func testFetchZoneChangesSuccessNoTokenNoMore() throws {
        let zoneIds = [CKRecordZone.ID(zoneName: "testZone1", ownerName: "testOwner"), CKRecordZone.ID(zoneName: "testZone2", ownerName: "testOwner"), CKRecordZone.ID(zoneName: "testZone3", ownerName: "testOwner")]
        let tokensMap = zoneIds.reduce(into: [CKRecordZone.ID: TestServerChangeToken](), {result, currentZone in
            let token = TestServerChangeToken(key: currentZone.zoneName)!
            result[currentZone] = token
        })
        let records = [CKRecord.ID(recordName: "aaa"), CKRecord.ID(recordName: "bbb"), CKRecord.ID(recordName: "ccc"), CKRecord.ID(recordName: "ddd")].map({CKRecord(recordType: CKRecord.RecordType("testRecordType"), recordID: $0)})
        let wrapper = ZonesToFetchWrapper(localDb: true, zoneIds: zoneIds)
        self.operations.onAddOperation = { operation, localOperations, sharedOperations in
            guard let operation = operation as? CKFetchRecordZoneChangesOperation else { return }
            for zoneId in zoneIds {
                let option = operation.configurationsByRecordZoneID?[zoneId]
                XCTAssert(option != nil)
                XCTAssert(option?.previousServerChangeToken == nil)
            }
            for record in records {
                operation.recordChangedBlock?(record)
            }
            for zoneId in zoneIds {
                operation.recordZoneFetchCompletionBlock?(zoneId, tokensMap[zoneId], nil, false, nil)
            }
            operation.fetchRecordZoneChangesCompletionBlock?(nil)
        }
        let resultRecords = try self.utils.fetchZoneChanges(wrapper: wrapper).toBlocking().first()!
        XCTAssert(self.operations.localOperations.count == 1)
        XCTAssert(resultRecords.elementsEqual(records))
        for zoneId in zoneIds {
            XCTAssert((self.storage.getZoneToken(zoneId: zoneId, localDb: true) as? TestServerChangeToken)?.key == zoneId.zoneName)
        }
    }
    
    func testFetchZoneChangesSuccessHasTokenNoMore() throws {
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
        let wrapper = ZonesToFetchWrapper(localDb: true, zoneIds: zoneIds)
        self.operations.onAddOperation = { operation, localOperations, sharedOperations in
            guard let operation = operation as? CKFetchRecordZoneChangesOperation else { return }
            for zoneId in zoneIds {
                let option = operation.configurationsByRecordZoneID?[zoneId]
                XCTAssert(option != nil)
                XCTAssert(option?.previousServerChangeToken != nil)
            }
            for record in records {
                operation.recordChangedBlock?(record)
            }
            for zoneId in zoneIds {
                operation.recordZoneFetchCompletionBlock?(zoneId, tokensMap[zoneId], nil, false, nil)
            }
            operation.fetchRecordZoneChangesCompletionBlock?(nil)
        }
        let resultRecords = try self.utils.fetchZoneChanges(wrapper: wrapper).toBlocking().first()!
        XCTAssert(self.operations.localOperations.count == 1)
        XCTAssert(resultRecords.elementsEqual(records))
        for zoneId in zoneIds {
            XCTAssert((self.storage.getZoneToken(zoneId: zoneId, localDb: true) as? TestServerChangeToken)?.key == zoneId.zoneName)
        }
    }
    
    func testFetchZoneChangesSuccessNoTokenHasMore() throws {
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
        let wrapper = ZonesToFetchWrapper(localDb: true, zoneIds: zoneIds)
        self.operations.onAddOperation = { operation, localOperations, sharedOperations in
            guard let operation = operation as? CKFetchRecordZoneChangesOperation else { return }
            if localOperations.count == 1 {
                for zoneId in zoneIds {
                    let option = operation.configurationsByRecordZoneID?[zoneId]
                    XCTAssert(option != nil)
                    XCTAssert(option?.previousServerChangeToken == nil)
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
                    XCTAssert(option != nil)
                    XCTAssert(option?.previousServerChangeToken != nil)
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
        let resultRecords = try self.utils.fetchZoneChanges(wrapper: wrapper).toBlocking().first()!
        XCTAssert(self.operations.localOperations.count == 2)
        XCTAssert(resultRecords.elementsEqual(records + records2))
        for zoneId in zoneIds {
            XCTAssert((self.storage.getZoneToken(zoneId: zoneId, localDb: true) as? TestServerChangeToken)?.key == (zoneId.zoneName + "2"))
        }
    }
    
    func testFetchZoneChangesSuccessResetToken() throws {
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
        let wrapper = ZonesToFetchWrapper(localDb: true, zoneIds: zoneIds)
        self.operations.onAddOperation = { operation, localOperations, sharedOperations in
            guard let operation = operation as? CKFetchRecordZoneChangesOperation else { return }
            if localOperations.count == 1 {
                for zoneId in zoneIds {
                    let option = operation.configurationsByRecordZoneID?[zoneId]
                    XCTAssert(option != nil)
                    XCTAssert(option?.previousServerChangeToken != nil)
                }
                for zoneId in zoneIds {
                    operation.recordZoneFetchCompletionBlock?(zoneId, tokensMap[zoneId], nil, true, CommonError(description: "token"))
                }
                operation.fetchRecordZoneChangesCompletionBlock?(CommonError(description: "token"))
            } else {
                for zoneId in zoneIds {
                    let option = operation.configurationsByRecordZoneID?[zoneId]
                    XCTAssert(option != nil)
                    XCTAssert(option?.previousServerChangeToken == nil)
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
        let resultRecords = try self.utils.fetchZoneChanges(wrapper: wrapper).toBlocking().first()!
        XCTAssert(self.operations.localOperations.count == 2)
        XCTAssert(resultRecords.elementsEqual(records))
        for zoneId in zoneIds {
            XCTAssert((self.storage.getZoneToken(zoneId: zoneId, localDb: true) as? TestServerChangeToken)?.key == (zoneId.zoneName))
        }
    }
    
    func testFetchZoneChangesSuccessRetry() throws {
        let zoneIds = [CKRecordZone.ID(zoneName: "testZone1", ownerName: "testOwner"), CKRecordZone.ID(zoneName: "testZone2", ownerName: "testOwner"), CKRecordZone.ID(zoneName: "testZone3", ownerName: "testOwner")]
        let tokensMap = zoneIds.reduce(into: [CKRecordZone.ID: TestServerChangeToken](), {result, currentZone in
            let token = TestServerChangeToken(key: currentZone.zoneName)!
            result[currentZone] = token
        })
        let records = [CKRecord.ID(recordName: "aaa"), CKRecord.ID(recordName: "bbb"), CKRecord.ID(recordName: "ccc"), CKRecord.ID(recordName: "ddd")].map({CKRecord(recordType: CKRecord.RecordType("testRecordType"), recordID: $0)})
        let wrapper = ZonesToFetchWrapper(localDb: true, zoneIds: zoneIds)
        self.operations.onAddOperation = { operation, localOperations, sharedOperations in
            guard let operation = operation as? CKFetchRecordZoneChangesOperation else { return }
            if localOperations.count == 1 {
                for zoneId in zoneIds {
                    let option = operation.configurationsByRecordZoneID?[zoneId]
                    XCTAssert(option != nil)
                    XCTAssert(option?.previousServerChangeToken == nil)
                }
                for zoneId in zoneIds {
                    operation.recordZoneFetchCompletionBlock?(zoneId, tokensMap[zoneId], nil, true, CommonError(description: "retry"))
                }
                operation.fetchRecordZoneChangesCompletionBlock?(CommonError(description: "retry"))
            } else {
                for zoneId in zoneIds {
                    let option = operation.configurationsByRecordZoneID?[zoneId]
                    XCTAssert(option != nil)
                    XCTAssert(option?.previousServerChangeToken == nil)
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
        let resultRecords = try self.utils.fetchZoneChanges(wrapper: wrapper).toBlocking().first()!
        XCTAssert(self.operations.localOperations.count == 2)
        XCTAssert(resultRecords.elementsEqual(records))
        for zoneId in zoneIds {
            XCTAssert((self.storage.getZoneToken(zoneId: zoneId, localDb: true) as? TestServerChangeToken)?.key == (zoneId.zoneName))
        }
    }
    
    func testFetchZoneChangesFail() {
        let zoneIds = [CKRecordZone.ID(zoneName: "testZone1", ownerName: "testOwner"), CKRecordZone.ID(zoneName: "testZone2", ownerName: "testOwner"), CKRecordZone.ID(zoneName: "testZone3", ownerName: "testOwner")]
        let wrapper = ZonesToFetchWrapper(localDb: true, zoneIds: zoneIds)
        self.operations.onAddOperation = { operation, localOperations, sharedOperations in
            guard let operation = operation as? CKFetchRecordZoneChangesOperation else { return }
            operation.fetchRecordZoneChangesCompletionBlock?(CommonError(description: "fail"))
        }
        do {
            _ = try self.utils.fetchZoneChanges(wrapper: wrapper).toBlocking().first()!
            XCTAssert(false)
        } catch {
            XCTAssert(error.localizedDescription == "fail")
        }
        XCTAssert(self.operations.localOperations.count == 1)
    }
}
