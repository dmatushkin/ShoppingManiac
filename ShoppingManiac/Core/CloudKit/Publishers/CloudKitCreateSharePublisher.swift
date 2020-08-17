//
//  CloudKitCreateSharePublisher.swift
//  ShoppingManiac
//
//  Created by Dmitry Matyushkin on 7/22/20.
//  Copyright © 2020 Dmitry Matyushkin. All rights reserved.
//

import Foundation
import Combine
import CloudKit
import SwiftyBeaver
import DependencyInjection

struct CloudKitCreateSharePublisher: Publisher {

	private final class CloudKitSubscription<S: Subscriber>: Subscription where S.Input == CKShare, S.Failure == Error {

		@Autowired
		private var cloudKitUtils: CloudKitUtilsProtocol
		private let wrapper: ShoppingListItemsWrapper
		private var subscriber: S?
		private var cancellable: Cancellable?

		init(wrapper: ShoppingListItemsWrapper, subscriber: S) {
			self.wrapper = wrapper
			self.subscriber = subscriber
		}

		func request(_ demand: Subscribers.Demand) {
			guard let subscriber = subscriber else { return }
			let share = CKShare(rootRecord: wrapper.record)
            share[CKShare.SystemFieldKey.title] = "Shopping list" as CKRecordValue
            share[CKShare.SystemFieldKey.shareType] = "org.md.ShoppingManiac" as CKRecordValue
            share.publicPermission = .readWrite

            let recordsToUpdate = [wrapper.record, share]
			let publisher: AnyPublisher<Void, Error> = cloudKitUtils.updateRecords(records: recordsToUpdate, localDb: true)
			self.cancellable = publisher.flatMap({[unowned self] in
				self.cloudKitUtils.updateRecords(records: self.wrapper.items, localDb: true)
			}).sink(receiveCompletion: { completion in
				subscriber.receive(completion: completion)
			}, receiveValue: {
				_ = subscriber.receive(share)
			})
		}

		func cancel() {
			subscriber = nil
		}
	}

	typealias Output = CKShare
	typealias Failure = Error

	private let wrapper: ShoppingListItemsWrapper

	init(wrapper: ShoppingListItemsWrapper) {
		self.wrapper = wrapper
	}

	func receive<S>(subscriber: S) where S: Subscriber, Self.Failure == S.Failure, Self.Output == S.Input {
			let subscription = CloudKitSubscription(wrapper: wrapper,
													subscriber: subscriber)
			subscriber.receive(subscription: subscription)
	}
}
