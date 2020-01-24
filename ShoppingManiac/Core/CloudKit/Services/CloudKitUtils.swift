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

class CloudKitUtils {
    
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
	
	private func createFetchRecordsOperation(recordIds: [CKRecord.ID], localDb: Bool, observer: AnyObserver<CKRecord>) -> CKFetchRecordsOperation {
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
			if let error = error {
				switch CloudKitErrorType.errorType(forError: error) {
				case .retry(let timeout):
					CloudKitUtils.retryQueue.asyncAfter(deadline: .now() + timeout) {[weak self] in
                        guard let self = self else { return }
                        self.operations.run(operation: self.createFetchRecordsOperation(recordIds: recordIds, localDb: localDb, observer: observer), localDb: localDb)
					}
				default:
					observer.onError(error)
				}
			} else {
				observer.onCompleted()
			}
		}
		operation.qualityOfService = .utility
		return operation
	}
    
    func fetchRecords(recordIds: [CKRecord.ID], localDb: Bool) -> Observable<CKRecord> {
        return Observable<CKRecord>.create {[weak self] observer in
            guard let self = self else { return Disposables.create() }
            self.operations.run(operation: self.createFetchRecordsOperation(recordIds: recordIds, localDb: localDb, observer: observer), localDb: localDb)
            return Disposables.create()
        }
    }
        
    func updateSubscriptions(subscriptions: [CKSubscription], localDb: Bool) -> Observable<Void> {
        return Observable<Void>.create {[weak self] observer in
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
			self?.operations.run(operation: operation, localDb: localDb)
            return Disposables.create()
        }
    }
    	
	private func createUpdateRecordsOperation(records: [CKRecord], localDb: Bool, observer: AnyObserver<Void>) -> CKModifyRecordsOperation {
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
			if let error = error {
                error.showError(title: "Sharing error")
				switch CloudKitErrorType.errorType(forError: error) {
				case .retry(let timeout):
					CloudKitUtils.retryQueue.asyncAfter(deadline: .now() + timeout) {[weak self] in
                        guard let self = self else { return }
                        self.operations.run(operation: self.createUpdateRecordsOperation(records: records, localDb: localDb, observer: observer), localDb: localDb)
					}
				default:
					observer.onError(error)
				}
			} else {
				SwiftyBeaver.debug("Records modification done successfully")
				observer.onCompleted()
			}
		}
		return modifyOperation
	}
    
    func updateRecords(records: [CKRecord], localDb: Bool) -> Observable<Void> {
        return Observable<Void>.create {[weak self] observer in
            guard let self = self else { return Disposables.create() }
            self.operations.run(operation: self.createUpdateRecordsOperation(records: records, localDb: localDb, observer: observer), localDb: localDb)
            return Disposables.create()
        }
    }
	
	private func createFetchDatabaseChangesOperation(loadedZoneIds: [CKRecordZone.ID], localDb: Bool, observer: AnyObserver<ZonesToFetchWrapper>) -> CKFetchDatabaseChangesOperation {
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
			if let error = error {
				SwiftyBeaver.debug(error.localizedDescription)
				switch CloudKitErrorType.errorType(forError: error) {
				case .retry(let timeout):
					CloudKitUtils.retryQueue.asyncAfter(deadline: .now() + timeout) {[weak self] in
                        guard let self = self else { return }
                        self.operations.run(operation: self.createFetchDatabaseChangesOperation(loadedZoneIds: loadedZoneIds, localDb: localDb, observer: observer), localDb: localDb)
					}
				case .tokenReset:
					self.storage.setDbToken(localDb: localDb, token: nil)
                    self.operations.run(operation: self.createFetchDatabaseChangesOperation(loadedZoneIds: loadedZoneIds, localDb: localDb, observer: observer), localDb: localDb)
				default:
					self.storage.setDbToken(localDb: localDb, token: nil)
					observer.onError(error)
				}
			} else if let token = token {
				self.storage.setDbToken(localDb: localDb, token: token)
				if moreComing {
                    self.operations.run(operation: self.createFetchDatabaseChangesOperation(loadedZoneIds: zoneIds, localDb: localDb, observer: observer), localDb: localDb)
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
		}
		return operation
	}
    
    func fetchDatabaseChanges(localDb: Bool) -> Observable<ZonesToFetchWrapper> {
        return Observable<ZonesToFetchWrapper>.create {[weak self] observer in
            guard let self = self else { return Disposables.create() }
            self.operations.run(operation: self.createFetchDatabaseChangesOperation(loadedZoneIds: [], localDb: localDb, observer: observer), localDb: localDb)
            return Disposables.create()
        }
    }
    	
	private func zoneIdFetchOption(zoneId: CKRecordZone.ID, localDb: Bool) -> CKFetchRecordZoneChangesOperation.ZoneConfiguration {
		let options = CKFetchRecordZoneChangesOperation.ZoneConfiguration()
		options.previousServerChangeToken = self.storage.getZoneToken(zoneId: zoneId, localDb: localDb)
		return options
	}
    
	private func createFetchZoneChangesOperation(loadedRecords: [CKRecord], wrapper: ZonesToFetchWrapper, observer: AnyObserver<[CKRecord]>) -> CKFetchRecordZoneChangesOperation {
		var records: [CKRecord] = loadedRecords
		var moreComingFlag: Bool = false
		let optionsByRecordZoneID = wrapper.zoneIds.reduce(into: [CKRecordZone.ID: CKFetchRecordZoneChangesOperation.ZoneConfiguration](), { $0[$1] = zoneIdFetchOption(zoneId: $1, localDb: wrapper.localDb) })
		let operation = CKFetchRecordZoneChangesOperation(recordZoneIDs: wrapper.zoneIds, configurationsByRecordZoneID: optionsByRecordZoneID)
		operation.fetchAllChanges = true
		operation.recordChangedBlock = { record in
			records.append(record)
		}
		operation.recordZoneChangeTokensUpdatedBlock = {[weak self] zoneId, token, data in
			self?.storage.setZoneToken(zoneId: zoneId, localDb: wrapper.localDb, token: token)
		}
		operation.recordZoneFetchCompletionBlock = {[weak self] zoneId, changeToken, data, moreComing, error in
			if let error = error {
				switch CloudKitErrorType.errorType(forError: error) {
				case .tokenReset:
					self?.storage.setZoneToken(zoneId: zoneId, localDb: wrapper.localDb, token: nil)
				default:
					break
				}
				SwiftyBeaver.debug(error.localizedDescription)
			} else if let token = changeToken {
				self?.storage.setZoneToken(zoneId: zoneId, localDb: wrapper.localDb, token: token)
			}
			if moreComing {
				moreComingFlag = true
			}
		}
		operation.fetchRecordZoneChangesCompletionBlock = {[weak self] error in
            guard let self = self else { return }
			if let error = error {
				SwiftyBeaver.debug(error.localizedDescription)
				switch CloudKitErrorType.errorType(forError: error) {
				case .retry(let timeout):
					CloudKitUtils.retryQueue.asyncAfter(deadline: .now() + timeout) {[weak self] in
                        guard let self = self else { return }
                        self.operations.run(operation: self.createFetchZoneChangesOperation(loadedRecords: loadedRecords, wrapper: wrapper, observer: observer), localDb: wrapper.localDb)
					}
				case .tokenReset:
                    self.operations.run(operation: self.createFetchZoneChangesOperation(loadedRecords: loadedRecords, wrapper: wrapper, observer: observer), localDb: wrapper.localDb)
				default:
					observer.onError(error)
				}
			} else {
				if moreComingFlag {
                    self.operations.run(operation: self.createFetchZoneChangesOperation(loadedRecords: records, wrapper: wrapper, observer: observer), localDb: wrapper.localDb)
				} else {
					SwiftyBeaver.debug("\(records.count) updated records found")
					observer.onNext(records)
					observer.onCompleted()
				}
			}
		}
		return operation
	}
	
    func fetchZoneChanges(wrapper: ZonesToFetchWrapper) -> Observable<[CKRecord]> {
        return Observable<[CKRecord]>.create {[weak self] observer in
            guard let self = self else { return Disposables.create() }
            if wrapper.zoneIds.count > 0 {
                self.operations.run(operation: self.createFetchZoneChangesOperation(loadedRecords: [], wrapper: wrapper, observer: observer), localDb: wrapper.localDb)
            } else {
                observer.onCompleted()
            }
            return Disposables.create()
        }
    }    
}
