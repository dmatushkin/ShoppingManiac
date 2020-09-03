//
//  CloudKitSyncUtilsPublishers.swift
//  CloudKitSyncTests
//
//  Created by Dmitry Matyushkin on 8/26/20.
//  Copyright © 2020 Dmitry Matyushkin. All rights reserved.
//

import Foundation
import Combine
import CloudKit
import SwiftyBeaver

//swiftlint:disable large_tuple

struct FetchRecordsTestPublisher: Publisher {

	private final class CloudKitSubscription<S: Subscriber>: Subscription where S.Input == CKRecord, S.Failure == Error {

		private let recordIds: [CKRecord.ID]
		private let localDb: Bool
		private var subscriber: S?
		private let onFetchRecords: (([CKRecord.ID], Bool) -> ([CKRecord], Error?))

		init(recordIds: [CKRecord.ID], localDb: Bool, subscriber: S, onFetchRecords: @escaping (([CKRecord.ID], Bool) -> ([CKRecord], Error?))) {
			self.recordIds = recordIds
			self.localDb = localDb
			self.subscriber = subscriber
			self.onFetchRecords = onFetchRecords
		}

		func request(_ demand: Subscribers.Demand) {
			guard let subscriber = subscriber else { return }
			CloudKitSyncUtilsStub.operationsQueue.async { [weak self] in
                guard let self = self else { fatalError() }
				SwiftyBeaver.debug("about to fetch records \(self.recordIds)")
				let result = self.onFetchRecords(self.recordIds, self.localDb)
				if let error = result.1 {
					subscriber.receive(completion: .failure(error))
				} else {
					for record in result.0 {
						_ = subscriber.receive(record)
					}
					subscriber.receive(completion: .finished)
				}
            }
		}

		func cancel() {
			subscriber = nil
		}
	}

	typealias Output = CKRecord
	typealias Failure = Error

	private let recordIds: [CKRecord.ID]
	private let localDb: Bool
	private let onFetchRecords: (([CKRecord.ID], Bool) -> ([CKRecord], Error?))

	init(recordIds: [CKRecord.ID], localDb: Bool, onFetchRecords: @escaping (([CKRecord.ID], Bool) -> ([CKRecord], Error?))) {
		self.recordIds = recordIds
		self.localDb = localDb
		self.onFetchRecords = onFetchRecords
	}

	func receive<S>(subscriber: S) where S: Subscriber, Self.Failure == S.Failure, Self.Output == S.Input {
			let subscription = CloudKitSubscription(recordIds: recordIds,
														localDb: localDb,
														subscriber: subscriber,
														onFetchRecords: onFetchRecords)
			subscriber.receive(subscription: subscription)
	}
}

struct UpdateRecordsTestPublisher: Publisher {

	private final class CloudKitSubscription<S: Subscriber>: Subscription where S.Input == Void, S.Failure == Error {

		private let records: [CKRecord]
		private let localDb: Bool
		private var subscriber: S?
		private let onUpdateRecords: (([CKRecord], Bool) -> Error?)

		init(records: [CKRecord], localDb: Bool, subscriber: S, onUpdateRecords: @escaping (([CKRecord], Bool) -> Error?)) {
			self.records = records
			self.localDb = localDb
			self.subscriber = subscriber
			self.onUpdateRecords = onUpdateRecords
		}

		func request(_ demand: Subscribers.Demand) {
			guard let subscriber = subscriber else { return }
			CloudKitSyncUtilsStub.operationsQueue.async { [weak self] in
                guard let self = self else { fatalError() }
				SwiftyBeaver.debug("about to update records \(self.records)")
				if let error = self.onUpdateRecords(self.records, self.localDb) {
					subscriber.receive(completion: .failure(error))
				} else {
					_ = subscriber.receive(())
					subscriber.receive(completion: .finished)
				}
            }
		}

		func cancel() {
			subscriber = nil
		}
	}

	typealias Output = Void
	typealias Failure = Error

	private let records: [CKRecord]
	private let localDb: Bool
	private let onUpdateRecords: (([CKRecord], Bool) -> Error?)

	init(records: [CKRecord], localDb: Bool, onUpdateRecords: @escaping (([CKRecord], Bool) -> Error?)) {
		self.records = records
		self.localDb = localDb
		self.onUpdateRecords = onUpdateRecords
	}

	func receive<S>(subscriber: S) where S: Subscriber, Self.Failure == S.Failure, Self.Output == S.Input {
			let subscription = CloudKitSubscription(records: records,
														localDb: localDb,
														subscriber: subscriber,
														onUpdateRecords: onUpdateRecords)
			subscriber.receive(subscription: subscription)
	}
}

struct UpdateSubscriptionsTestPublisher: Publisher {

	private final class CloudKitSubscription<S: Subscriber>: Subscription where S.Input == Void, S.Failure == Error {

		private let subscriptions: [CKSubscription]
		private let localDb: Bool
		private var subscriber: S?
		private let onUpdateSubscriptions: (([CKSubscription], Bool) -> Error?)

		init(subscriptions: [CKSubscription], localDb: Bool, subscriber: S, onUpdateSubscriptions: @escaping (([CKSubscription], Bool) -> Error?)) {
			self.subscriptions = subscriptions
			self.localDb = localDb
			self.subscriber = subscriber
			self.onUpdateSubscriptions = onUpdateSubscriptions
		}

		func request(_ demand: Subscribers.Demand) {
			guard let subscriber = subscriber else { return }
			CloudKitSyncUtilsStub.operationsQueue.async { [weak self] in
                guard let self = self else { fatalError() }
				SwiftyBeaver.debug("about to update subscriptions \(self.subscriptions)")
				if let error = self.onUpdateSubscriptions(self.subscriptions, self.localDb) {
					subscriber.receive(completion: .failure(error))
				} else {
					_ = subscriber.receive(())
					subscriber.receive(completion: .finished)
				}
            }
		}

		func cancel() {
			subscriber = nil
		}
	}

	typealias Output = Void
	typealias Failure = Error

	private let subscriptions: [CKSubscription]
	private let localDb: Bool
	private let onUpdateSubscriptions: (([CKSubscription], Bool) -> Error?)

	init(subscriptions: [CKSubscription], localDb: Bool, onUpdateSubscriptions: @escaping (([CKSubscription], Bool) -> Error?)) {
		self.subscriptions = subscriptions
		self.localDb = localDb
		self.onUpdateSubscriptions = onUpdateSubscriptions
	}

	func receive<S>(subscriber: S) where S: Subscriber, Self.Failure == S.Failure, Self.Output == S.Input {
			let subscription = CloudKitSubscription(subscriptions: subscriptions,
														localDb: localDb,
														subscriber: subscriber,
														onUpdateSubscriptions: onUpdateSubscriptions)
			subscriber.receive(subscription: subscription)
	}
}

struct FetchDatabaseChangesTestPublisher: Publisher {

	private final class CloudKitSubscription<S: Subscriber>: Subscription where S.Input == [CKRecordZone.ID], S.Failure == Error {

		private var loadedZoneIds: [CKRecordZone.ID] = []
		private let localDb: Bool
		private var subscriber: S?
		private let onFetchDatabaseChanges: ((Bool) -> ([CKRecordZone.ID], Error?))

		init(localDb: Bool, subscriber: S, onFetchDatabaseChanges: @escaping ((Bool) -> ([CKRecordZone.ID], Error?))) {
			self.localDb = localDb
			self.subscriber = subscriber
			self.onFetchDatabaseChanges = onFetchDatabaseChanges
		}

		func request(_ demand: Subscribers.Demand) {
			guard let subscriber = subscriber else { return }
			CloudKitSyncUtilsStub.operationsQueue.async { [weak self] in
                guard let self = self else { fatalError() }
                SwiftyBeaver.debug("about to fetch database changes")
				let result = self.onFetchDatabaseChanges(self.localDb)
				if let error = result.1 {
					subscriber.receive(completion: .failure(error))
				} else {
					_ = subscriber.receive(result.0)
					subscriber.receive(completion: .finished)
				}
            }
		}

		func cancel() {
			subscriber = nil
		}
	}

	typealias Output = [CKRecordZone.ID]
	typealias Failure = Error

	private let localDb: Bool
	private let onFetchDatabaseChanges: ((Bool) -> ([CKRecordZone.ID], Error?))

	init(localDb: Bool, onFetchDatabaseChanges: @escaping ((Bool) -> ([CKRecordZone.ID], Error?))) {
		self.localDb = localDb
		self.onFetchDatabaseChanges = onFetchDatabaseChanges
	}

	func receive<S>(subscriber: S) where S: Subscriber, Self.Failure == S.Failure, Self.Output == S.Input {
			let subscription = CloudKitSubscription(localDb: localDb,
													subscriber: subscriber,
													onFetchDatabaseChanges: onFetchDatabaseChanges)
			subscriber.receive(subscription: subscription)
	}
}

struct FetchZoneChangesTestPublisher: Publisher {

	private final class CloudKitSubscription<S: Subscriber>: Subscription where S.Input == [CKRecord], S.Failure == Error {

		private var records: [CKRecord] = []
		private let zoneIds: [CKRecordZone.ID]
		private var subscriber: S?
		private let onFetchZoneChanges: (([CKRecordZone.ID]) -> ([CKRecord], Error?))

		init(zoneIds: [CKRecordZone.ID], subscriber: S, onFetchZoneChanges: @escaping (([CKRecordZone.ID]) -> ([CKRecord], Error?))) {
			self.zoneIds = zoneIds
			self.subscriber = subscriber
			self.onFetchZoneChanges = onFetchZoneChanges
		}

		func request(_ demand: Subscribers.Demand) {
			guard let subscriber = subscriber else { return }
			CloudKitSyncUtilsStub.operationsQueue.async { [weak self] in
                guard let self = self else { fatalError() }
				SwiftyBeaver.debug("about to fetch zone changes \(self.zoneIds)")
				let result = self.onFetchZoneChanges(self.zoneIds)
				if let error = result.1 {
					subscriber.receive(completion: .failure(error))
				} else {
					_ = subscriber.receive(result.0)
					subscriber.receive(completion: .finished)
				}
            }
		}

		func cancel() {
			subscriber = nil
		}
	}

	typealias Output = [CKRecord]
	typealias Failure = Error

	private let zoneIds: [CKRecordZone.ID]
	private let onFetchZoneChanges: (([CKRecordZone.ID]) -> ([CKRecord], Error?))

	init(zoneIds: [CKRecordZone.ID], onFetchZoneChanges: @escaping (([CKRecordZone.ID]) -> ([CKRecord], Error?))) {
		self.zoneIds = zoneIds
		self.onFetchZoneChanges = onFetchZoneChanges
	}

	func receive<S>(subscriber: S) where S: Subscriber, Self.Failure == S.Failure, Self.Output == S.Input {
			let subscription = CloudKitSubscription(zoneIds: zoneIds,
													subscriber: subscriber,
													onFetchZoneChanges: onFetchZoneChanges)
			subscriber.receive(subscription: subscription)
	}
}

struct CloudKitAcceptShareTestPublisher: Publisher {

	private final class CloudKitSubscription<S: Subscriber>: Subscription where S.Input == (CKShare.Metadata, CKShare?), S.Failure == Error {

		private let metadata: CKShare.Metadata
		private let onAcceptShare: ((CKShare.Metadata) -> (CKShare.Metadata, CKShare?, Error?))
		private var subscriber: S?

		init(metadata: CKShare.Metadata, onAcceptShare: @escaping ((CKShare.Metadata) -> (CKShare.Metadata, CKShare?, Error?)), subscriber: S) {
			self.metadata = metadata
			self.subscriber = subscriber
			self.onAcceptShare = onAcceptShare
		}

		func request(_ demand: Subscribers.Demand) {
			guard let subscriber = subscriber else { return }

			CloudKitSyncUtilsStub.operationsQueue.async { [weak self] in
				guard let self = self else { fatalError() }
				SwiftyBeaver.debug("about to accept share \(self.metadata)")
				let result = self.onAcceptShare(self.metadata)
				if let error = result.2 {
					subscriber.receive(completion: .failure(error))
				} else {
					_ = subscriber.receive((result.0, result.1))
					subscriber.receive(completion: .finished)
				}
			}
		}

		func cancel() {
			subscriber = nil
		}
	}

	typealias Output = (CKShare.Metadata, CKShare?)
	typealias Failure = Error

	private let metadata: CKShare.Metadata
	private let onAcceptShare: ((CKShare.Metadata) -> (CKShare.Metadata, CKShare?, Error?))

	init(metadata: CKShare.Metadata, onAcceptShare: @escaping ((CKShare.Metadata) -> (CKShare.Metadata, CKShare?, Error?))) {
		self.metadata = metadata
		self.onAcceptShare = onAcceptShare
	}

	func receive<S>(subscriber: S) where S: Subscriber, Self.Failure == S.Failure, Self.Output == S.Input {
		let subscription = CloudKitSubscription(metadata: metadata,
												onAcceptShare: onAcceptShare,
												subscriber: subscriber)
		subscriber.receive(subscription: subscription)
	}
}
