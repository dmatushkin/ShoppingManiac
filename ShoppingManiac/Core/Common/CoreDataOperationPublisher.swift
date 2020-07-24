//
//  CoreDataOperationPublisher.swift
//  ShoppingManiac
//
//  Created by Dmitry Matyushkin on 7/23/20.
//  Copyright © 2020 Dmitry Matyushkin. All rights reserved.
//

import Foundation
import Combine
import CoreStore
import CoreData

struct CoreDataOperationPublisher<R>: Publisher {

	private final class CloudKitSubscription<S: Subscriber>: Subscription where S.Input == R, S.Failure == Error {

		private let operation: (AsynchronousDataTransaction) throws -> R
		private var subscriber: S?

		init(operation: @escaping (AsynchronousDataTransaction) throws -> R, subscriber: S) {
			self.operation = operation
			self.subscriber = subscriber
		}

		func request(_ demand: Subscribers.Demand) {
			guard let subscriber = subscriber else { return }
			CoreStoreDefaults.dataStack.perform(asynchronous: {[unowned self] transaction in
				return try self.operation(transaction)
			}, completion: {result in
				switch result {
				case .success(let value):
					if let coreDataObject = (value as? NSManagedObject).flatMap({ CoreStoreDefaults.dataStack.fetchExisting($0) }).flatMap({ $0 as? R }) {
						_ = subscriber.receive(coreDataObject)
					} else {
						_ = subscriber.receive(value)
					}
					subscriber.receive(completion: .finished)
				case .failure(let error):
					subscriber.receive(completion: .failure(error))
				}
			})
		}

		func cancel() {
			subscriber = nil
		}
	}

	private let operation: (AsynchronousDataTransaction) throws -> R

	init(operation: @escaping (AsynchronousDataTransaction) throws -> R) {
		self.operation = operation
	}

	func receive<S>(subscriber: S) where S: Subscriber, Self.Failure == S.Failure, Self.Output == S.Input {
		let subscription = CloudKitSubscription(operation: operation, subscriber: subscriber)
		subscriber.receive(subscription: subscription)
	}

	typealias Output = R
	typealias Failure = Error
}
