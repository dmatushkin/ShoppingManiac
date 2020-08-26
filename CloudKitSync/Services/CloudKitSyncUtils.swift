//
//  CloudKitSyncUtils.swift
//  CloudKitSync
//
//  Created by Dmitry Matyushkin on 8/14/20.
//  Copyright © 2020 Dmitry Matyushkin. All rights reserved.
//

import Foundation
import CloudKit
import SwiftyBeaver
import Combine
import DependencyInjection

public protocol CloudKitSyncUtilsProtocol {
	func fetchRecords(recordIds: [CKRecord.ID], localDb: Bool) -> AnyPublisher<CKRecord, Error>
	func updateSubscriptions(subscriptions: [CKSubscription], localDb: Bool) -> AnyPublisher<Void, Error>
	func updateRecords(records: [CKRecord], localDb: Bool) -> AnyPublisher<Void, Error>
	func fetchDatabaseChanges(localDb: Bool) -> AnyPublisher<[CKRecordZone.ID], Error>
	func fetchZoneChanges(zoneIds: [CKRecordZone.ID], localDb: Bool) -> AnyPublisher<[CKRecord], Error>
}

final class CloudKitSyncUtils: CloudKitSyncUtilsProtocol, DIDependency {

    static let retryQueue = DispatchQueue(label: "CloudKitUtils.retryQueue", attributes: .concurrent)

	init() {}

	func fetchRecords(recordIds: [CKRecord.ID], localDb: Bool) -> AnyPublisher<CKRecord, Error> {
		return CloudKitFetchRecordsPublisher(recordIds: recordIds, localDb: localDb).eraseToAnyPublisher()
	}

	func updateSubscriptions(subscriptions: [CKSubscription], localDb: Bool) -> AnyPublisher<Void, Error> {
		return CloudKitUpdateSubscriptionsPublisher(subscriptions: subscriptions, localDb: localDb).eraseToAnyPublisher()
	}

	func updateRecords(records: [CKRecord], localDb: Bool) -> AnyPublisher<Void, Error> {
		return CloudKitUpdateRecordsPublisher(records: records, localDb: localDb).eraseToAnyPublisher()
	}

	func fetchDatabaseChanges(localDb: Bool) -> AnyPublisher<[CKRecordZone.ID], Error> {
		return CloudKitFetchDatabaseChangesPublisher(localDb: localDb).eraseToAnyPublisher()
	}

	func fetchZoneChanges(zoneIds: [CKRecordZone.ID], localDb: Bool) -> AnyPublisher<[CKRecord], Error> {
		return CloudKitFetchZoneChangesPublisher(zoneIds: zoneIds, localDb: localDb).eraseToAnyPublisher()
	}
}
