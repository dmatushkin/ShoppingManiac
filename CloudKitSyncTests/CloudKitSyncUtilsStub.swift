//
//  CloudKitSyncUtilsStub.swift
//  CloudKitSyncTests
//
//  Created by Dmitry Matyushkin on 8/26/20.
//  Copyright © 2020 Dmitry Matyushkin. All rights reserved.
//

import Foundation
import CloudKit
import SwiftyBeaver
import Combine
@testable import CloudKitSync

//swiftlint:disable large_tuple

class CloudKitSyncUtilsStub: CloudKitSyncUtilsProtocol {

    static let operationsQueue = DispatchQueue(label: "CloudKitUtilsStub.operationsQueue", attributes: .concurrent)

    var onFetchRecords: (([CKRecord.ID], Bool) -> ([CKRecord], Error?))?
    var onUpdateRecords: (([CKRecord], Bool) -> Error?)?
    var onUpdateSubscriptions: (([CKSubscription], Bool) -> Error?)?
    var onFetchDatabaseChanges: ((Bool) -> ([CKRecordZone.ID], Error?))?
    var onFetchZoneChanges: (([CKRecordZone.ID]) -> ([CKRecord], Error?))?
	var onAcceptShare: ((CKShare.Metadata) -> (CKShare.Metadata, CKShare?, Error?))?

    func cleanup() {
        self.onFetchRecords = nil
        self.onUpdateRecords = nil
        self.onUpdateSubscriptions = nil
        self.onFetchDatabaseChanges = nil
        self.onFetchZoneChanges = nil
    }

	func fetchRecords(recordIds: [CKRecord.ID], localDb: Bool) -> AnyPublisher<CKRecord, Error> {
		guard let onFetchRecords = self.onFetchRecords else { fatalError() }
		return FetchRecordsTestPublisher(recordIds: recordIds, localDb: localDb, onFetchRecords: onFetchRecords).eraseToAnyPublisher()
	}

	func updateSubscriptions(subscriptions: [CKSubscription], localDb: Bool) -> AnyPublisher<Void, Error> {
		guard let onUpdateSubscriptions = self.onUpdateSubscriptions else { fatalError() }
		return UpdateSubscriptionsTestPublisher(subscriptions: subscriptions, localDb: localDb, onUpdateSubscriptions: onUpdateSubscriptions).eraseToAnyPublisher()
	}

	func updateRecords(records: [CKRecord], localDb: Bool) -> AnyPublisher<Void, Error> {
		guard let onUpdateRecords = self.onUpdateRecords else { fatalError() }
		return UpdateRecordsTestPublisher(records: records, localDb: localDb, onUpdateRecords: onUpdateRecords).eraseToAnyPublisher()
	}

	func fetchDatabaseChanges(localDb: Bool) -> AnyPublisher<[CKRecordZone.ID], Error> {
		guard let onFetchDatabaseChanges = self.onFetchDatabaseChanges else { fatalError() }
		return FetchDatabaseChangesTestPublisher(localDb: localDb, onFetchDatabaseChanges: onFetchDatabaseChanges).eraseToAnyPublisher()
	}

	func fetchZoneChanges(zoneIds: [CKRecordZone.ID], localDb: Bool) -> AnyPublisher<[CKRecord], Error> {
		guard let onFetchZoneChanges = self.onFetchZoneChanges else { fatalError() }
		return FetchZoneChangesTestPublisher(zoneIds: zoneIds, onFetchZoneChanges: onFetchZoneChanges).eraseToAnyPublisher()
	}

	func acceptShare(metadata: CKShare.Metadata) -> AnyPublisher<(CKShare.Metadata, CKShare?), Error> {
		guard let onAcceptShare = self.onAcceptShare else { fatalError() }
		return CloudKitAcceptShareTestPublisher(metadata: metadata, onAcceptShare: onAcceptShare).eraseToAnyPublisher()
	}
}
