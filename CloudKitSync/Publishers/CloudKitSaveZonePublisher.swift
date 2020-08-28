//
//  CloudKitSaveZonePublisher.swift
//  CloudKitSync
//
//  Created by Dmitry Matyushkin on 8/28/20.
//  Copyright © 2020 Dmitry Matyushkin. All rights reserved.
//

import Foundation
import CloudKit
import Combine
import DependencyInjection

struct CloudKitSaveZonePublisher: Publisher {

	private final class CloudKitSubscription<S: Subscriber>: Subscription where S.Input == Void, S.Failure == Error {

		@Autowired
		private var operations: CloudKitSyncOperationsProtocol
		private let zone: CKRecordZone
		private var subscriber: S?

		init(zone: CKRecordZone, subscriber: S) {
			self.zone = zone
			self.subscriber = subscriber
		}

		func request(_ demand: Subscribers.Demand) {
			guard let subscriber = subscriber else { return }
			operations.saveZone(zone) { (_, error) in
				if let error = error {
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
	private let zone: CKRecordZone

	init(zone: CKRecordZone) {
		self.zone = zone
	}

	func receive<S>(subscriber: S) where S: Subscriber, Self.Failure == S.Failure, Self.Output == S.Input {
		let subscription = CloudKitSubscription(zone: zone, subscriber: subscriber)
		subscriber.receive(subscription: subscription)
	}
}
