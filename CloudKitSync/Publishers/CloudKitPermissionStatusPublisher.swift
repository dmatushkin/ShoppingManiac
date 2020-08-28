//
//  CloudKitPermissionStatusPublisher.swift
//  CloudKitSync
//
//  Created by Dmitry Matyushkin on 8/28/20.
//  Copyright © 2020 Dmitry Matyushkin. All rights reserved.
//

import Foundation
import CloudKit
import Combine
import DependencyInjection

struct CloudKitPermissionStatusPublisher: Publisher {

	private final class CloudKitSubscription<S: Subscriber>: Subscription where S.Input == CKContainer_Application_PermissionStatus, S.Failure == Error {

		@Autowired
		private var operations: CloudKitSyncOperationsProtocol
		private let permission: CKContainer_Application_Permissions
		private var subscriber: S?

		init(permission: CKContainer_Application_Permissions, subscriber: S) {
			self.permission = permission
			self.subscriber = subscriber
		}

		func request(_ demand: Subscribers.Demand) {
			guard let subscriber = subscriber else { return }
			operations.permissionStatus(forApplicationPermission: permission, completionHandler: { (status, error) in
				if let error = error {
					subscriber.receive(completion: .failure(error))
				} else {
					_ = subscriber.receive(status)
					subscriber.receive(completion: .finished)
				}
			})
		}

		func cancel() {
			subscriber = nil
		}
	}

	typealias Output = CKContainer_Application_PermissionStatus
	typealias Failure = Error
	private let permission: CKContainer_Application_Permissions

	init(permission: CKContainer_Application_Permissions) {
		self.permission = permission
	}

	func receive<S>(subscriber: S) where S: Subscriber, Self.Failure == S.Failure, Self.Output == S.Input {
		let subscription = CloudKitSubscription(permission: permission, subscriber: subscriber)
		subscriber.receive(subscription: subscription)
	}
}
