//
//  CloudKitUtilsPublishers.swift
//  ShoppingManiacUnitTests
//
//  Created by Dmitry Matyushkin on 7/23/20.
//  Copyright © 2020 Dmitry Matyushkin. All rights reserved.
//

import Foundation
import Combine
import CloudKit
import SwiftyBeaver
import CloudKitSync

struct FetchRecordsTestPublisher: Publisher {

	private final class CloudKitSubscription<S: Subscriber>: Subscription where S.Input == CKRecord, S.Failure == Error {

		private let recordIds: [CKRecord.ID]
		private let localDb: Bool
		private var subscriber: S?
		private let onFetchRecords: (([CKRecord.ID], Bool) -> [CKRecord])

		init(recordIds: [CKRecord.ID], localDb: Bool, subscriber: S, onFetchRecords: @escaping (([CKRecord.ID], Bool) -> [CKRecord])) {
			self.recordIds = recordIds
			self.localDb = localDb
			self.subscriber = subscriber
			self.onFetchRecords = onFetchRecords
		}

		func request(_ demand: Subscribers.Demand) {
			guard let subscriber = subscriber else { return }
			CloudKitUtilsStub.operationsQueue.async { [weak self] in
                guard let self = self else { fatalError() }
				SwiftyBeaver.debug("about to fetch records \(self.recordIds)")
				let result = self.onFetchRecords(self.recordIds, self.localDb)
				for record in result {
					_ = subscriber.receive(record)
				}
				subscriber.receive(completion: .finished)
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
	private let onFetchRecords: (([CKRecord.ID], Bool) -> [CKRecord])

	init(recordIds: [CKRecord.ID], localDb: Bool, onFetchRecords: @escaping (([CKRecord.ID], Bool) -> [CKRecord])) {
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
		private let onUpdateRecords: (([CKRecord], Bool) -> Void)

		init(records: [CKRecord], localDb: Bool, subscriber: S, onUpdateRecords: @escaping (([CKRecord], Bool) -> Void)) {
			self.records = records
			self.localDb = localDb
			self.subscriber = subscriber
			self.onUpdateRecords = onUpdateRecords
		}

		func request(_ demand: Subscribers.Demand) {
			guard let subscriber = subscriber else { return }
			CloudKitUtilsStub.operationsQueue.async { [weak self] in
                guard let self = self else { fatalError() }
				SwiftyBeaver.debug("about to update records \(self.records)")
				_ = self.onUpdateRecords(self.records, self.localDb)
				_ = subscriber.receive(())
				subscriber.receive(completion: .finished)
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
	private let onUpdateRecords: (([CKRecord], Bool) -> Void)

	init(records: [CKRecord], localDb: Bool, onUpdateRecords: @escaping (([CKRecord], Bool) -> Void)) {
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
		private let onUpdateSubscriptions: (([CKSubscription], Bool) -> Void)

		init(subscriptions: [CKSubscription], localDb: Bool, subscriber: S, onUpdateSubscriptions: @escaping (([CKSubscription], Bool) -> Void)) {
			self.subscriptions = subscriptions
			self.localDb = localDb
			self.subscriber = subscriber
			self.onUpdateSubscriptions = onUpdateSubscriptions
		}

		func request(_ demand: Subscribers.Demand) {
			guard let subscriber = subscriber else { return }
			CloudKitUtilsStub.operationsQueue.async { [weak self] in
                guard let self = self else { fatalError() }
				SwiftyBeaver.debug("about to update subscriptions \(self.subscriptions)")
				_ = self.onUpdateSubscriptions(self.subscriptions, self.localDb)
				_ = subscriber.receive(())
				subscriber.receive(completion: .finished)
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
	private let onUpdateSubscriptions: (([CKSubscription], Bool) -> Void)

	init(subscriptions: [CKSubscription], localDb: Bool, onUpdateSubscriptions: @escaping (([CKSubscription], Bool) -> Void)) {
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
		private let onFetchDatabaseChanges: ((Bool) -> [CKRecordZone.ID])

		init(localDb: Bool, subscriber: S, onFetchDatabaseChanges: @escaping ((Bool) -> [CKRecordZone.ID])) {
			self.localDb = localDb
			self.subscriber = subscriber
			self.onFetchDatabaseChanges = onFetchDatabaseChanges
		}

		func request(_ demand: Subscribers.Demand) {
			guard let subscriber = subscriber else { return }
			CloudKitUtilsStub.operationsQueue.async { [weak self] in
                guard let self = self else { fatalError() }
                SwiftyBeaver.debug("about to fetch database changes")
				let result = self.onFetchDatabaseChanges(self.localDb)
				_ = subscriber.receive(result)
				subscriber.receive(completion: .finished)
            }
		}

		func cancel() {
			subscriber = nil
		}
	}

	typealias Output = [CKRecordZone.ID]
	typealias Failure = Error

	private let localDb: Bool
	private let onFetchDatabaseChanges: ((Bool) -> [CKRecordZone.ID])

	init(localDb: Bool, onFetchDatabaseChanges: @escaping ((Bool) -> [CKRecordZone.ID])) {
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
		private let onFetchZoneChanges: (([CKRecordZone.ID]) -> [CKRecord])

		init(zoneIds: [CKRecordZone.ID], subscriber: S, onFetchZoneChanges: @escaping (([CKRecordZone.ID]) -> [CKRecord])) {
			self.zoneIds = zoneIds
			self.subscriber = subscriber
			self.onFetchZoneChanges = onFetchZoneChanges
		}

		func request(_ demand: Subscribers.Demand) {
			guard let subscriber = subscriber else { return }
			CloudKitUtilsStub.operationsQueue.async { [weak self] in
                guard let self = self else { fatalError() }
				SwiftyBeaver.debug("about to fetch zone changes \(self.zoneIds)")
				let result = self.onFetchZoneChanges(self.zoneIds)
				_ = subscriber.receive(result)
				subscriber.receive(completion: .finished)
            }
		}

		func cancel() {
			subscriber = nil
		}
	}

	typealias Output = [CKRecord]
	typealias Failure = Error

	private let zoneIds: [CKRecordZone.ID]
	private let onFetchZoneChanges: (([CKRecordZone.ID]) -> [CKRecord])

	init(zoneIds: [CKRecordZone.ID], onFetchZoneChanges: @escaping (([CKRecordZone.ID]) -> [CKRecord])) {
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
