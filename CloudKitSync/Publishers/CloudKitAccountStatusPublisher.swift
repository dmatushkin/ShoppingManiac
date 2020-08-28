//
//  CloudKitAccountStatusPublisher.swift
//  CloudKitSync
//
//  Created by Dmitry Matyushkin on 8/28/20.
//  Copyright © 2020 Dmitry Matyushkin. All rights reserved.
//

import Foundation
import CloudKit
import Combine
import DependencyInjection

struct CloudKitAccountStatusPublisher: Publisher {

	private final class CloudKitSubscription<S: Subscriber>: Subscription where S.Input == CKAccountStatus, S.Failure == Error {

		@Autowired
		private var operations: CloudKitSyncOperationsProtocol
		private var subscriber: S?

		init(subscriber: S) {
			self.subscriber = subscriber
		}

		func request(_ demand: Subscribers.Demand) {
			guard let subscriber = subscriber else { return }
			operations.accountStatus { (status, error) in
				if let error = error {
					subscriber.receive(completion: .failure(error))
				} else {
					_ = subscriber.receive(status)
					subscriber.receive(completion: .finished)
				}
			}
		}

		func cancel() {
			subscriber = nil
		}
	}

	typealias Output = CKAccountStatus
	typealias Failure = Error

	init() {
	}

	func receive<S>(subscriber: S) where S: Subscriber, Self.Failure == S.Failure, Self.Output == S.Input {
		let subscription = CloudKitSubscription(subscriber: subscriber)
		subscriber.receive(subscription: subscription)
	}
}
