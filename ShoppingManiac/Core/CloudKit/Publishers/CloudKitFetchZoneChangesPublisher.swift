//
//  CloudKitFetchZoneChangesPublisher.swift
//  ShoppingManiac
//
//  Created by Dmitry Matyushkin on 7/22/20.
//  Copyright © 2020 Dmitry Matyushkin. All rights reserved.
//

import Foundation
import Combine
import CloudKit
import SwiftyBeaver

struct CloudKitFetchZoneChangesPublisher: Publisher {

	private final class CloudKitSubscription<S: Subscriber>: Subscription where S.Input == [CKRecord], S.Failure == Error {

		@Autowired
		private var operations: CloudKitOperationsProtocol
		@Autowired
		private var storage: CloudKitTokenStorgeProtocol
		private var records: [CKRecord] = []
		private let wrapper: ZonesToFetchWrapper
		private var subscriber: S?

		init(wrapper: ZonesToFetchWrapper, subscriber: S) {
			self.wrapper = wrapper
			self.subscriber = subscriber
		}

		private func zoneIdFetchOption(zoneId: CKRecordZone.ID, localDb: Bool) -> CKFetchRecordZoneChangesOperation.ZoneConfiguration {
			let options = CKFetchRecordZoneChangesOperation.ZoneConfiguration()
			options.previousServerChangeToken = self.storage.getZoneToken(zoneId: zoneId, localDb: localDb)
			return options
		}

		private func handleFetchZoneChangesDone(moreComingFlag: Bool, error: Error?) {
			guard let subscriber = subscriber else { return }
			error?.log()
			switch CloudKitErrorType.errorType(forError: error) {
			case .retry(let timeout):
				CloudKitUtils.retryQueue.asyncAfter(deadline: .now() + timeout) {[weak self] in
					self?.request()
				}
			case .tokenReset:
				self.request()
			case .noError:
				if moreComingFlag {
					self.request()
				} else {
					SwiftyBeaver.debug("\(self.records.count) updated records found")
					_ = subscriber.receive(self.records)
					subscriber.receive(completion: .finished)
				}
			default:
				subscriber.receive(completion: .failure(error!))
			}
		}

		func request(_ demand: Subscribers.Demand) {
			request()
		}

		func request() {
			guard subscriber != nil else { return }
			var moreComingFlag: Bool = false
			let optionsByRecordZoneID = wrapper.zoneIds.reduce(into: [CKRecordZone.ID: CKFetchRecordZoneChangesOperation.ZoneConfiguration](), { $0[$1] = zoneIdFetchOption(zoneId: $1, localDb: wrapper.localDb) })
			let operation = CKFetchRecordZoneChangesOperation(recordZoneIDs: wrapper.zoneIds, configurationsByRecordZoneID: optionsByRecordZoneID)
			operation.fetchAllChanges = true
			operation.recordChangedBlock = { record in self.records.append(record) }
			operation.recordZoneChangeTokensUpdatedBlock = {[weak self] zoneId, token, data in
				guard let self = self else { return }
				self.storage.setZoneToken(zoneId: zoneId, localDb: self.wrapper.localDb, token: token)
			}
			operation.recordZoneFetchCompletionBlock = {[weak self] zoneId, changeToken, data, moreComing, error in
				guard let self = self else { return }
				error?.log()
				switch CloudKitErrorType.errorType(forError: error) {
				case .tokenReset:
					self.storage.setZoneToken(zoneId: zoneId, localDb: self.wrapper.localDb, token: nil)
				case .noError:
					if let token = changeToken {
						self.storage.setZoneToken(zoneId: zoneId, localDb: self.wrapper.localDb, token: token)
					}
				default:
					break
				}
				if moreComing {
					moreComingFlag = true
				}
			}
			operation.fetchRecordZoneChangesCompletionBlock = {[weak self] error in
				self?.handleFetchZoneChangesDone(moreComingFlag: moreComingFlag, error: error)
			}
			operation.qualityOfService = .utility
			operation.fetchAllChanges = true
			self.operations.run(operation: operation, localDb: wrapper.localDb)
		}

		func cancel() {
			subscriber = nil
		}
	}

	typealias Output = [CKRecord]
	typealias Failure = Error

	private let wrapper: ZonesToFetchWrapper

	init(wrapper: ZonesToFetchWrapper) {
		self.wrapper = wrapper
	}

	func receive<S>(subscriber: S) where S: Subscriber, Self.Failure == S.Failure, Self.Output == S.Input {
			let subscription = CloudKitSubscription(wrapper: wrapper,
													subscriber: subscriber)
			subscriber.receive(subscription: subscription)
	}
}
