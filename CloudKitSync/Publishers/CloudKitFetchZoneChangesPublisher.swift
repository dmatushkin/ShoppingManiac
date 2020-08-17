//
//  CloudKitFetchZoneChangesPublisher.swift
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

struct CloudKitFetchZoneChangesPublisher: Publisher {

	private final class CloudKitSubscription<S: Subscriber>: Subscription where S.Input == [CKRecord], S.Failure == Error {

		@Autowired
		private var operations: CloudKitSyncOperationsProtocol
		@Autowired
		private var storage: CloudKitSyncTokenStorageProtocol
		private var records: [CKRecord] = []
		private let zoneIds: [CKRecordZone.ID]
		private let localDb: Bool
		private var subscriber: S?

		init(zoneIds: [CKRecordZone.ID], localDb: Bool, subscriber: S) {
			self.zoneIds = zoneIds
			self.localDb = localDb
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
			switch CloudKitSyncErrorType.errorType(forError: error) {
			case .retry(let timeout):
				CloudKitSyncUtils.retryQueue.asyncAfter(deadline: .now() + timeout) {[weak self] in
					self?.request()
				}
			case .tokenReset:
				self.request()
			case .noError:
				if moreComingFlag {
					self.request()
				} else {
					CommonError.logDebug("\(self.records.count) updated records found")
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
			guard let subscriber = subscriber else { return }
			guard zoneIds.count > 0 else {
				_ = subscriber.receive([])
				subscriber.receive(completion: .finished)
				return
			}
			var moreComingFlag: Bool = false
			let optionsByRecordZoneID = zoneIds.reduce(into: [CKRecordZone.ID: CKFetchRecordZoneChangesOperation.ZoneConfiguration](), { $0[$1] = zoneIdFetchOption(zoneId: $1, localDb: localDb) })
			let operation = CKFetchRecordZoneChangesOperation(recordZoneIDs: zoneIds, configurationsByRecordZoneID: optionsByRecordZoneID)
			operation.fetchAllChanges = true
			operation.recordChangedBlock = { record in self.records.append(record) }
			operation.recordZoneChangeTokensUpdatedBlock = {[weak self] zoneId, token, data in
				guard let self = self else { return }
				self.storage.setZoneToken(zoneId: zoneId, localDb: self.localDb, token: token)
			}
			operation.recordZoneFetchCompletionBlock = {[weak self] zoneId, changeToken, data, moreComing, error in
				guard let self = self else { return }
				error?.log()
				switch CloudKitSyncErrorType.errorType(forError: error) {
				case .tokenReset:
					self.storage.setZoneToken(zoneId: zoneId, localDb: self.localDb, token: nil)
				case .noError:
					if let token = changeToken {
						self.storage.setZoneToken(zoneId: zoneId, localDb: self.localDb, token: token)
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
			self.operations.run(operation: operation, localDb: self.localDb)
		}

		func cancel() {
			subscriber = nil
		}
	}

	typealias Output = [CKRecord]
	typealias Failure = Error

	private let zoneIds: [CKRecordZone.ID]
	private let localDb: Bool

	init(zoneIds: [CKRecordZone.ID], localDb: Bool) {
		self.zoneIds = zoneIds
		self.localDb = localDb
	}

	func receive<S>(subscriber: S) where S: Subscriber, Self.Failure == S.Failure, Self.Output == S.Input {
			let subscription = CloudKitSubscription(zoneIds: zoneIds,
													localDb: localDb,
													subscriber: subscriber)
			subscriber.receive(subscription: subscription)
	}
}
