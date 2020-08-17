//
//  CloudKitUpdateSubscriptionsPublisher.swift
//  CloudKitSync
//
//  Created by Dmitry Matyushkin on 8/14/20.
//  Copyright © 2020 Dmitry Matyushkin. All rights reserved.
//

import Foundation
import Combine
import CloudKit
import CommonError
import DependencyInjection

struct CloudKitUpdateSubscriptionsPublisher: Publisher {

	private final class CloudKitSubscription<S: Subscriber>: Subscription where S.Input == Void, S.Failure == Error {

		@Autowired
		private var operations: CloudKitSyncOperationsProtocol
		private let subscriptions: [CKSubscription]
		private let localDb: Bool
		private var subscriber: S?

		init(subscriptions: [CKSubscription], localDb: Bool, subscriber: S) {
			self.subscriptions = subscriptions
			self.localDb = localDb
			self.subscriber = subscriber
		}

		func request(_ demand: Subscribers.Demand) {
			guard let subscriber = subscriber else { return }
			guard subscriptions.count > 0 else {
				_ = subscriber.receive(())
				subscriber.receive(completion: .finished)
				return
			}
			let operation = CKModifySubscriptionsOperation(subscriptionsToSave: subscriptions, subscriptionIDsToDelete: [])
			operation.modifySubscriptionsCompletionBlock = { (_, _, error) in
				if let error = error {
					error.log()
					_ = subscriber.receive(())
					subscriber.receive(completion: .finished)
				} else {
					_ = subscriber.receive(())
					subscriber.receive(completion: .finished)
				}
			}
			operation.qualityOfService = .utility
			self.operations.run(operation: operation, localDb: localDb)
		}

		func cancel() {
			subscriber = nil
		}
	}

	typealias Output = Void
	typealias Failure = Error

	private let subscriptions: [CKSubscription]
	private let localDb: Bool

	init(subscriptions: [CKSubscription], localDb: Bool) {
		self.subscriptions = subscriptions
		self.localDb = localDb
	}

	func receive<S>(subscriber: S) where S: Subscriber, Self.Failure == S.Failure, Self.Output == S.Input {
			let subscription = CloudKitSubscription(subscriptions: subscriptions,
														localDb: localDb,
														subscriber: subscriber)
			subscriber.receive(subscription: subscription)
	}
}
