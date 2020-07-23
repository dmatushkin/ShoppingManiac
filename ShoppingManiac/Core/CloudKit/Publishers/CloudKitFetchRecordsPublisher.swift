//
//  CloudKitFetchRecordsPublisher.swift
//  ShoppingManiac
//
//  Created by Dmitry Matyushkin on 7/22/20.
//  Copyright © 2020 Dmitry Matyushkin. All rights reserved.
//

import Foundation
import Combine
import CloudKit
import SwiftyBeaver

struct CloudKitFetchRecordsPublisher: Publisher {

	private final class CloudKitSubscription<S: Subscriber>: Subscription where S.Input == CKRecord, S.Failure == Error {

		@Autowired
		private var operations: CloudKitOperationsProtocol
		private let recordIds: [CKRecord.ID]
		private let localDb: Bool
		private var subscriber: S?

		init(recordIds: [CKRecord.ID], localDb: Bool, subscriber: S) {
			self.recordIds = recordIds
			self.localDb = localDb
			self.subscriber = subscriber
		}

		func request(_ demand: Subscribers.Demand) {
			guard let subscriber = subscriber else { return }
			let operation = CKFetchRecordsOperation(recordIDs: recordIds)
			operation.perRecordCompletionBlock = { record, recordid, error in
				error?.log()
				if let record = record {
					SwiftyBeaver.debug("Successfully loaded record \(recordid?.recordName ?? "no record name")")
					_ = subscriber.receive(record)
				}
			}
			operation.fetchRecordsCompletionBlock = { _, error in
				error?.log()
				switch CloudKitErrorType.errorType(forError: error) {
				case .retry(let timeout):
					CloudKitUtils.retryQueue.asyncAfter(deadline: .now() + timeout) {[weak self] in
						self?.request(demand)
					}
				case .noError:
					subscriber.receive(completion: .finished)
				default:
					subscriber.receive(completion: .failure(error!))
				}
			}
			operation.qualityOfService = .utility
			self.operations.run(operation: operation, localDb: localDb)
		}

		func cancel() {
			subscriber = nil
		}
	}

	typealias Output = CKRecord
	typealias Failure = Error

	private let recordIds: [CKRecord.ID]
	private let localDb: Bool

	init(recordIds: [CKRecord.ID], localDb: Bool) {
		self.recordIds = recordIds
		self.localDb = localDb
	}

	func receive<S>(subscriber: S) where S: Subscriber, Self.Failure == S.Failure, Self.Output == S.Input {
			let subscription = CloudKitSubscription(recordIds: recordIds,
														localDb: localDb,
														subscriber: subscriber)
			subscriber.receive(subscription: subscription)
	}
}
