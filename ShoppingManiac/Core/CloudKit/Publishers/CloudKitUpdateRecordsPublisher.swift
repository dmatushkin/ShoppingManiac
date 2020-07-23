//
//  CloudKitUpdateRecordsPublisher.swift
//  ShoppingManiac
//
//  Created by Dmitry Matyushkin on 7/22/20.
//  Copyright © 2020 Dmitry Matyushkin. All rights reserved.
//

import Foundation
import Combine
import CloudKit
import SwiftyBeaver

struct CloudKitUpdateRecordsPublisher: Publisher {

	private final class CloudKitSubscription<S: Subscriber>: Subscription where S.Input == Void, S.Failure == Error {

		@Autowired
		private var operations: CloudKitOperationsProtocol
		private let records: [CKRecord]
		private let localDb: Bool
		private var subscriber: S?

		init(records: [CKRecord], localDb: Bool, subscriber: S) {
			self.records = records
			self.localDb = localDb
			self.subscriber = subscriber
		}

		func request(_ demand: Subscribers.Demand) {
			guard let subscriber = subscriber else { return }
			let operation = CKModifyRecordsOperation(recordsToSave: records, recordIDsToDelete: nil)
			operation.perRecordCompletionBlock = { _, error in
				error?.log()
			}
			operation.modifyRecordsCompletionBlock = { _, recordIds, error in
				error?.log()
				switch CloudKitErrorType.errorType(forError: error) {
				case .retry(let timeout):
					CloudKitUtils.retryQueue.asyncAfter(deadline: .now() + timeout) {[weak self] in
						self?.request(demand)
					}
				case .noError:
					SwiftyBeaver.debug("Records modification done successfully")
					_ = subscriber.receive(())
					subscriber.receive(completion: .finished)
				default:
					error?.showError(title: "Sharing error")
					subscriber.receive(completion: .failure(error!))
				}
			}
			operation.qualityOfService = .utility
			operation.savePolicy = .allKeys
			self.operations.run(operation: operation, localDb: localDb)
		}

		func cancel() {
			subscriber = nil
		}
	}

	typealias Output = Void
	typealias Failure = Error

	private let records: [CKRecord]
	private let localDb: Bool

	init(records: [CKRecord], localDb: Bool) {
		self.records = records
		self.localDb = localDb
	}

	func receive<S>(subscriber: S) where S: Subscriber, Self.Failure == S.Failure, Self.Output == S.Input {
			let subscription = CloudKitSubscription(records: records,
														localDb: localDb,
														subscriber: subscriber)
			subscriber.receive(subscription: subscription)
	}
}
