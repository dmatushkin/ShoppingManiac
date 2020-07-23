//
//  CloudKitFetchDatabaseChangesPublisher.swift
//  ShoppingManiac
//
//  Created by Dmitry Matyushkin on 7/22/20.
//  Copyright © 2020 Dmitry Matyushkin. All rights reserved.
//

import Foundation
import Combine
import CloudKit
import SwiftyBeaver

struct CloudKitFetchDatabaseChangesPublisher: Publisher {

	private final class CloudKitSubscription<S: Subscriber>: Subscription where S.Input == ZonesToFetchWrapper, S.Failure == Error {

		@Autowired
		private var operations: CloudKitOperationsProtocol
		@Autowired
		private var storage: CloudKitTokenStorgeProtocol
		private var loadedZoneIds: [CKRecordZone.ID] = []
		private let localDb: Bool
		private var subscriber: S?

		init(localDb: Bool, subscriber: S) {
			self.localDb = localDb
			self.subscriber = subscriber
		}

		func request(_ demand: Subscribers.Demand) {
			guard let subscriber = subscriber else { return }
			let operation = CKFetchDatabaseChangesOperation(previousServerChangeToken: self.storage.getDbToken(localDb: localDb))
			operation.recordZoneWithIDChangedBlock = {[weak self] zoneId in
				guard let self = self else { return }
				self.loadedZoneIds.append(zoneId)
			}
			operation.changeTokenUpdatedBlock = {[weak self] token in
				guard let self = self else { return }
				self.storage.setDbToken(localDb: self.localDb, token: token)
			}
			operation.fetchDatabaseChangesCompletionBlock = {[weak self] token, moreComing, error in
				guard let self = self else { return }
				error?.log()
				switch CloudKitErrorType.errorType(forError: error) {
				case .retry(let timeout):
					CloudKitUtils.retryQueue.asyncAfter(deadline: .now() + timeout) {[weak self] in
						self?.request(demand)
					}
				case .tokenReset:
					self.storage.setDbToken(localDb: self.localDb, token: nil)
					self.request(demand)
				case .noError:
					if let token = token {
						self.storage.setDbToken(localDb: self.localDb, token: token)
						if moreComing {
							self.request(demand)
						} else {
							_ = subscriber.receive(ZonesToFetchWrapper(localDb: self.localDb, zoneIds: self.loadedZoneIds))
							SwiftyBeaver.debug("Update zones request finished")
							subscriber.receive(completion: .finished)
						}
					} else {
						let error = CommonError(description: "iCloud token is empty")
						error.log()
						subscriber.receive(completion: .failure(error))
					}
				default:
					self.storage.setDbToken(localDb: self.localDb, token: nil)
					subscriber.receive(completion: .failure(error!))
				}
			}
			operation.qualityOfService = .utility
			operation.fetchAllChanges = true
			self.operations.run(operation: operation, localDb: localDb)
		}

		func cancel() {
			subscriber = nil
		}
	}

	typealias Output = ZonesToFetchWrapper
	typealias Failure = Error

	private let localDb: Bool

	init(localDb: Bool) {
		self.localDb = localDb
	}

	func receive<S>(subscriber: S) where S: Subscriber, Self.Failure == S.Failure, Self.Output == S.Input {
			let subscription = CloudKitSubscription(localDb: localDb,
													subscriber: subscriber)
			subscriber.receive(subscription: subscription)
	}
}
