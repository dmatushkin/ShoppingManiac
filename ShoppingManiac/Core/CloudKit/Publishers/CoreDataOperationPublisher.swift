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

struct CoreDataOperationPublisher<I, R>: Publisher {

	private final class CloudKitSubscription<S: Subscriber>: Subscription where S.Input == R, S.Failure == Error {

		private let input: I
		private var subscriber: S?

		init(input: I, subscriber: S) {
			self.input = input
			self.subscriber = subscriber
		}

		func request(_ demand: Subscribers.Demand) {
			guard let subscriber = subscriber else { return }
		}

		func cancel() {
			subscriber = nil
		}
	}

	private let input: I

	init(input: I) {
		self.input = input
	}

	func receive<S>(subscriber: S) where S : Subscriber, Self.Failure == S.Failure, Self.Output == S.Input {
		let subscription = CloudKitSubscription(input: input, subscriber: subscriber)
		subscriber.receive(subscription: subscription)
	}

	typealias Output = R
	typealias Failure = Error
}
