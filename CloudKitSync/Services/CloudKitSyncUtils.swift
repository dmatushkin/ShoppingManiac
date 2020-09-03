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
	func acceptShare(metadata: CKShare.Metadata) -> AnyPublisher<(CKShare.Metadata, CKShare?), Error>
}

public final class CloudKitSyncUtils: CloudKitSyncUtilsProtocol, DIDependency {

    static let retryQueue = DispatchQueue(label: "CloudKitUtils.retryQueue", attributes: .concurrent)

	public init() {}

	public func fetchRecords(recordIds: [CKRecord.ID], localDb: Bool) -> AnyPublisher<CKRecord, Error> {
		return CloudKitFetchRecordsPublisher(recordIds: recordIds, localDb: localDb).eraseToAnyPublisher()
	}

	public func updateSubscriptions(subscriptions: [CKSubscription], localDb: Bool) -> AnyPublisher<Void, Error> {
		return CloudKitUpdateSubscriptionsPublisher(subscriptions: subscriptions, localDb: localDb).eraseToAnyPublisher()
	}

	public func updateRecords(records: [CKRecord], localDb: Bool) -> AnyPublisher<Void, Error> {
		return CloudKitUpdateRecordsPublisher(records: records, localDb: localDb).eraseToAnyPublisher()
	}

	public func fetchDatabaseChanges(localDb: Bool) -> AnyPublisher<[CKRecordZone.ID], Error> {
		return CloudKitFetchDatabaseChangesPublisher(localDb: localDb).eraseToAnyPublisher()
	}

	public func fetchZoneChanges(zoneIds: [CKRecordZone.ID], localDb: Bool) -> AnyPublisher<[CKRecord], Error> {
		return CloudKitFetchZoneChangesPublisher(zoneIds: zoneIds, localDb: localDb).eraseToAnyPublisher()
	}

	public func acceptShare(metadata: CKShare.Metadata) -> AnyPublisher<(CKShare.Metadata, CKShare?), Error> {
		return CloudKitAcceptSharePublisher(metadata: metadata).eraseToAnyPublisher()
	}
}
