//
//  CloudKitUtils.swift
//  ShoppingManiac
//
//  Created by Dmitry Matyushkin on 28/04/2018.
//  Copyright © 2018 Dmitry Matyushkin. All rights reserved.
//

import Foundation
import CloudKit
import SwiftyBeaver
import RxSwift

protocol CloudKitUtilsProtocol {
    func fetchRecords(recordIds: [CKRecord.ID], localDb: Bool) -> Observable<CKRecord>
    func updateSubscriptions(subscriptions: [CKSubscription], localDb: Bool) -> Observable<Void>
    func updateRecords(records: [CKRecord], localDb: Bool) -> Observable<Void>
    func fetchDatabaseChanges(localDb: Bool) -> Observable<ZonesToFetchWrapper>
    func fetchZoneChanges(wrapper: ZonesToFetchWrapper) -> Observable<[CKRecord]>
}

class CloudKitUtils: CloudKitUtilsProtocol {
    
    private static let retryQueue = DispatchQueue(label: "CloudKitUtils.retryQueue", attributes: .concurrent)
    
    static let zoneName = "ShareZone"
    static let listRecordType = "ShoppingList"
    static let itemRecordType = "ShoppingListItem"
    
    private let operations: CloudKitOperationsProtocol
    private let storage: CloudKitTokenStorgeProtocol
    
    init(operations: CloudKitOperationsProtocol, storage: CloudKitTokenStorgeProtocol) {
        self.operations = operations
        self.storage = storage
    }
	
	private func createFetchRecordsOperation(recordIds: [CKRecord.ID], localDb: Bool, observer: AnyObserver<CKRecord>) {
		let operation = CKFetchRecordsOperation(recordIDs: recordIds)
		operation.perRecordCompletionBlock = { record, recordid, error in
			if let error = error {
				SwiftyBeaver.debug(error.localizedDescription)
			} else if let record = record {
				SwiftyBeaver.debug("Successfully loaded record \(recordid?.recordName ?? "no record name")")
				observer.onNext(record)
			}
		}
		operation.fetchRecordsCompletionBlock = { _, error in
			switch CloudKitErrorType.errorType(forError: error) {
			case .retry(let timeout):
				CloudKitUtils.retryQueue.asyncAfter(deadline: .now() + timeout) {[weak self] in
					self?.createFetchRecordsOperation(recordIds: recordIds, localDb: localDb, observer: observer)
				}
			case .noError:
				observer.onCompleted()
			default:
				observer.onError(error!)
			}
		}
		operation.qualityOfService = .utility
        self.operations.run(operation: operation, localDb: localDb)
	}
    
    func fetchRecords(recordIds: [CKRecord.ID], localDb: Bool) -> Observable<CKRecord> {
        return Observable<CKRecord>.create {[weak self] observer in
            self?.createFetchRecordsOperation(recordIds: recordIds, localDb: localDb, observer: observer)
            return Disposables.create()
        }
    }
	
	private func createUpdateSubscriptionsOperation(subscriptions: [CKSubscription], localDb: Bool, observer: AnyObserver<Void>) {
		let operation = CKModifySubscriptionsOperation(subscriptionsToSave: subscriptions, subscriptionIDsToDelete: [])
		operation.modifySubscriptionsCompletionBlock = { (_, _, error) in
			if let error = error {
				SwiftyBeaver.error(error.localizedDescription)
				observer.onCompleted()
				//observer.onError(error)
			} else {
				observer.onCompleted()
			}
		}
		operation.qualityOfService = .utility
		self.operations.run(operation: operation, localDb: localDb)
	}
        
    func updateSubscriptions(subscriptions: [CKSubscription], localDb: Bool) -> Observable<Void> {
        return Observable<Void>.create {[weak self] observer in
			self?.createUpdateSubscriptionsOperation(subscriptions: subscriptions, localDb: localDb, observer: observer)
            return Disposables.create()
        }
    }
    	
	private func createUpdateRecordsOperation(records: [CKRecord], localDb: Bool, observer: AnyObserver<Void>) {
		let modifyOperation = CKModifyRecordsOperation(recordsToSave: records, recordIDsToDelete: nil)
		modifyOperation.savePolicy = .allKeys
		modifyOperation.perRecordCompletionBlock = {record, error in
			if let error = error {
				SwiftyBeaver.debug("Error while saving records \(error.localizedDescription)")
			} else {
				SwiftyBeaver.debug("Successfully saved record \(record.recordID.recordName)")
			}
		}
		modifyOperation.modifyRecordsCompletionBlock = { _, recordIds, error in
			switch CloudKitErrorType.errorType(forError: error) {
			case .retry(let timeout):
				CloudKitUtils.retryQueue.asyncAfter(deadline: .now() + timeout) {[weak self] in
					self?.createUpdateRecordsOperation(records: records, localDb: localDb, observer: observer)
				}
			case .noError:
				SwiftyBeaver.debug("Records modification done successfully")
				observer.onCompleted()
			default:
				error?.showError(title: "Sharing error")
				observer.onError(error!)
			}
		}
        self.operations.run(operation: modifyOperation, localDb: localDb)
	}
    
    func updateRecords(records: [CKRecord], localDb: Bool) -> Observable<Void> {
        return Observable<Void>.create {[weak self] observer in
            self?.createUpdateRecordsOperation(records: records, localDb: localDb, observer: observer)
            return Disposables.create()
        }
    }
	
	private func createFetchDatabaseChangesOperation(loadedZoneIds: [CKRecordZone.ID], localDb: Bool, observer: AnyObserver<ZonesToFetchWrapper>) {
		let operation = CKFetchDatabaseChangesOperation(previousServerChangeToken: self.storage.getDbToken(localDb: localDb))
		operation.fetchAllChanges = true
		var zoneIds: [CKRecordZone.ID] = loadedZoneIds
		operation.recordZoneWithIDChangedBlock = { zoneId in
			zoneIds.append(zoneId)
		}
		operation.changeTokenUpdatedBlock = {[weak self] token in
			self?.storage.setDbToken(localDb: localDb, token: token)
		}
		operation.qualityOfService = .utility
		operation.fetchAllChanges = true
		operation.fetchDatabaseChangesCompletionBlock = {[weak self] token, moreComing, error in
            guard let self = self else { return }
			switch CloudKitErrorType.errorType(forError: error) {
			case .retry(let timeout):
				CloudKitUtils.retryQueue.asyncAfter(deadline: .now() + timeout) {[weak self] in
					self?.createFetchDatabaseChangesOperation(loadedZoneIds: loadedZoneIds, localDb: localDb, observer: observer)
				}
			case .tokenReset:
				self.storage.setDbToken(localDb: localDb, token: nil)
				self.createFetchDatabaseChangesOperation(loadedZoneIds: loadedZoneIds, localDb: localDb, observer: observer)
			case .noError:
				if let token = token {
					self.storage.setDbToken(localDb: localDb, token: token)
					if moreComing {
						self.createFetchDatabaseChangesOperation(loadedZoneIds: zoneIds, localDb: localDb, observer: observer)
					} else {
						observer.onNext(ZonesToFetchWrapper(localDb: localDb, zoneIds: zoneIds))
						SwiftyBeaver.debug("Update zones request finished")
						observer.onCompleted()
					}
				} else {
					let error = CommonError(description: "iCloud token is empty")
					SwiftyBeaver.debug(error.localizedDescription)
					observer.onError(error)
				}
			default:
				self.storage.setDbToken(localDb: localDb, token: nil)
				observer.onError(error!)
			}
		}
        self.operations.run(operation: operation, localDb: localDb)
	}
    
    func fetchDatabaseChanges(localDb: Bool) -> Observable<ZonesToFetchWrapper> {
        return Observable<ZonesToFetchWrapper>.create {[weak self] observer in
            self?.createFetchDatabaseChangesOperation(loadedZoneIds: [], localDb: localDb, observer: observer)
            return Disposables.create()
        }
    }
    	
	private func zoneIdFetchOption(zoneId: CKRecordZone.ID, localDb: Bool) -> CKFetchRecordZoneChangesOperation.ZoneConfiguration {
		let options = CKFetchRecordZoneChangesOperation.ZoneConfiguration()
		options.previousServerChangeToken = self.storage.getZoneToken(zoneId: zoneId, localDb: localDb)
		return options
	}
    
    //swiftlint:disable cyclomatic_complexity
	private func createFetchZoneChangesOperation(loadedRecords: [CKRecord], wrapper: ZonesToFetchWrapper, observer: AnyObserver<[CKRecord]>) {
		var records: [CKRecord] = loadedRecords
		var moreComingFlag: Bool = false
		let optionsByRecordZoneID = wrapper.zoneIds.reduce(into: [CKRecordZone.ID: CKFetchRecordZoneChangesOperation.ZoneConfiguration](), { $0[$1] = zoneIdFetchOption(zoneId: $1, localDb: wrapper.localDb) })
		let operation = CKFetchRecordZoneChangesOperation(recordZoneIDs: wrapper.zoneIds, configurationsByRecordZoneID: optionsByRecordZoneID)
		operation.fetchAllChanges = true
		operation.recordChangedBlock = { record in records.append(record) }
		operation.recordZoneChangeTokensUpdatedBlock = {[weak self] zoneId, token, data in self?.storage.setZoneToken(zoneId: zoneId, localDb: wrapper.localDb, token: token) }
		operation.recordZoneFetchCompletionBlock = {[weak self] zoneId, changeToken, data, moreComing, error in
			switch CloudKitErrorType.errorType(forError: error) {
			case .tokenReset:
				self?.storage.setZoneToken(zoneId: zoneId, localDb: wrapper.localDb, token: nil)
			case .noError:
				if let token = changeToken {
					self?.storage.setZoneToken(zoneId: zoneId, localDb: wrapper.localDb, token: token)
				}
			default:
				break
			}
			if moreComing {
				moreComingFlag = true
			}
		}
		operation.fetchRecordZoneChangesCompletionBlock = {[weak self] error in
            guard let self = self else { return }
			switch CloudKitErrorType.errorType(forError: error) {
			case .retry(let timeout):
				CloudKitUtils.retryQueue.asyncAfter(deadline: .now() + timeout) {[weak self] in
					self?.createFetchZoneChangesOperation(loadedRecords: loadedRecords, wrapper: wrapper, observer: observer)
				}
			case .tokenReset:
				self.createFetchZoneChangesOperation(loadedRecords: loadedRecords, wrapper: wrapper, observer: observer)
			case .noError:
				if moreComingFlag {
                    self.createFetchZoneChangesOperation(loadedRecords: records, wrapper: wrapper, observer: observer)
				} else {
					SwiftyBeaver.debug("\(records.count) updated records found")
					observer.onNext(records)
					observer.onCompleted()
				}
			default:
				observer.onError(error!)
			}
		}
        self.operations.run(operation: operation, localDb: wrapper.localDb)
	}
	
    func fetchZoneChanges(wrapper: ZonesToFetchWrapper) -> Observable<[CKRecord]> {
        return Observable<[CKRecord]>.create {[weak self] observer in
            if wrapper.zoneIds.count > 0 {
                self?.createFetchZoneChangesOperation(loadedRecords: [], wrapper: wrapper, observer: observer)
            } else {
                observer.onCompleted()
            }
            return Disposables.create()
        }
    }    
}
