//
//  CloudKitAcceptSharePublisher.swift
//  CloudKitSync
//
//  Created by Dmitry Matyushkin on 9/3/20.
//  Copyright © 2020 Dmitry Matyushkin. All rights reserved.
//

import Foundation
import Combine
import CloudKit
import CommonError
import DependencyInjection

struct CloudKitAcceptSharePublisher: Publisher {

	private final class CloudKitSubscription<S: Subscriber>: Subscription where S.Input == (CKShare.Metadata, CKShare?), S.Failure == Error {

		@Autowired
		private var operations: CloudKitSyncOperationsProtocol
		private let metadata: CKShare.Metadata
		private var subscriber: S?

		init(metadata: CKShare.Metadata, subscriber: S) {
			self.metadata = metadata
			self.subscriber = subscriber
		}

		func request(_ demand: Subscribers.Demand) {
			guard let subscriber = subscriber else { return }
			let operation = CKAcceptSharesOperation(shareMetadatas: [metadata])
			operation.qualityOfService = .userInteractive
			operation.perShareCompletionBlock = { metadata, share, error in
				if let error = error {
					error.log()
					subscriber.receive(completion: .failure(error))
				} else {
					_ = subscriber.receive((metadata, share))
					subscriber.receive(completion: .finished)
				}
			}
			operations.run(operation: operation)
		}

		func cancel() {
			subscriber = nil
		}
	}

	typealias Output = (CKShare.Metadata, CKShare?)
	typealias Failure = Error

	private let metadata: CKShare.Metadata

	init(metadata: CKShare.Metadata) {
		self.metadata = metadata
	}

	func receive<S>(subscriber: S) where S: Subscriber, Self.Failure == S.Failure, Self.Output == S.Input {
		let subscription = CloudKitSubscription(metadata: metadata,
												subscriber: subscriber)
		subscriber.receive(subscription: subscription)
	}
}
