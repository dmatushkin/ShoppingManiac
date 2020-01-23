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

enum CloudKitErrorType {
	case failure(error: Error)
	case retry(timeout: Double)
	case tokenReset
	
	static func errorType(forError error: Error) -> CloudKitErrorType {
		guard let ckError = error as? CKError else {
			return .failure(error: error)
		}
		switch ckError.code {
		case .serviceUnavailable, .requestRateLimited, .zoneBusy:
			if let retry = ckError.userInfo[CKErrorRetryAfterKey] as? Double {
				return .retry(timeout: retry)
			} else {
				return .failure(error: error)
			}
		case .changeTokenExpired:
			return .tokenReset
		default:
			return .failure(error: error)
		}
	}
}

class CloudKitUtils {
    
    static let zoneName = "ShareZone"
    static let listRecordType = "ShoppingList"
    static let itemRecordType = "ShoppingListItem"
    
    private init() {}
	
	private class func createFetchRecordsOperation(recordIds: [CKRecord.ID], localDb: Bool, observer: AnyObserver<CKRecord>) -> CKFetchRecordsOperation {
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
					DispatchQueue.main.asyncAfter(deadline: .now() + timeout) {
						CloudKitOperations.run(operation: createFetchRecordsOperation(recordIds: recordIds, localDb: localDb, observer: observer), localDb: localDb)
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
    
    class func fetchRecords(recordIds: [CKRecord.ID], localDb: Bool) -> Observable<CKRecord> {
        return Observable<CKRecord>.create { observer in
			CloudKitOperations.run(operation: createFetchRecordsOperation(recordIds: recordIds, localDb: localDb, observer: observer), localDb: localDb)
            return Disposables.create()
        }
    }
        
    class func updateSubscriptions(subscriptions: [CKSubscription], localDb: Bool) -> Observable<Void> {
        return Observable<Void>.create { observer in
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
			CloudKitOperations.run(operation: operation, localDb: localDb)
            return Disposables.create()
        }
    }
    	
	private class func createUpdateRecordsOperation(records: [CKRecord], localDb: Bool, observer: AnyObserver<Void>) -> CKModifyRecordsOperation {
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
				AppDelegate.showAlert(title: "Sharing error", message: error.localizedDescription)
				switch CloudKitErrorType.errorType(forError: error) {
				case .retry(let timeout):
					DispatchQueue.main.asyncAfter(deadline: .now() + timeout) {
						CloudKitOperations.run(operation: createUpdateRecordsOperation(records: records, localDb: localDb, observer: observer), localDb: localDb)
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
    
    class func updateRecords(records: [CKRecord], localDb: Bool) -> Observable<Void> {
        return Observable<Void>.create { observer in
			CloudKitOperations.run(operation: createUpdateRecordsOperation(records: records, localDb: localDb, observer: observer), localDb: localDb)
            return Disposables.create()
        }
    }
	
	private class func createFetchDatabaseChangesOperation(loadedZoneIds: [CKRecordZone.ID], localDb: Bool, observer: AnyObserver<ZonesToFetchWrapper>) -> CKFetchDatabaseChangesOperation {
		let operation = CKFetchDatabaseChangesOperation(previousServerChangeToken: CloudKitTokenStorage.getDbToken(localDb: localDb))
		operation.fetchAllChanges = true
		var zoneIds: [CKRecordZone.ID] = loadedZoneIds
		operation.recordZoneWithIDChangedBlock = { zoneId in
			zoneIds.append(zoneId)
		}
		operation.changeTokenUpdatedBlock = { token in
			CloudKitTokenStorage.setDbToken(localDb: localDb, token: token)
		}
		operation.qualityOfService = .utility
		operation.fetchAllChanges = true
		operation.fetchDatabaseChangesCompletionBlock = { token, moreComing, error in
			if let error = error {
				SwiftyBeaver.debug(error.localizedDescription)
				switch CloudKitErrorType.errorType(forError: error) {
				case .retry(let timeout):
					DispatchQueue.main.asyncAfter(deadline: .now() + timeout) {
						CloudKitOperations.run(operation: createFetchDatabaseChangesOperation(loadedZoneIds: loadedZoneIds, localDb: localDb, observer: observer), localDb: localDb)
					}
				case .tokenReset:
					CloudKitTokenStorage.setDbToken(localDb: localDb, token: nil)
					CloudKitOperations.run(operation: createFetchDatabaseChangesOperation(loadedZoneIds: loadedZoneIds, localDb: localDb, observer: observer), localDb: localDb)
				default:
					CloudKitTokenStorage.setDbToken(localDb: localDb, token: nil)
					observer.onError(error)
				}
			} else if let token = token {
				CloudKitTokenStorage.setDbToken(localDb: localDb, token: token)
				if moreComing {
					CloudKitOperations.run(operation: createFetchDatabaseChangesOperation(loadedZoneIds: zoneIds, localDb: localDb, observer: observer), localDb: localDb)
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
    
    class func fetchDatabaseChanges(localDb: Bool) -> Observable<ZonesToFetchWrapper> {
        return Observable<ZonesToFetchWrapper>.create { observer in
			CloudKitOperations.run(operation: createFetchDatabaseChangesOperation(loadedZoneIds: [], localDb: localDb, observer: observer), localDb: localDb)
            return Disposables.create()
        }
    }
    	
	private class func zoneIdFetchOption(zoneId: CKRecordZone.ID, localDb: Bool) -> CKFetchRecordZoneChangesOperation.ZoneConfiguration {
		let options = CKFetchRecordZoneChangesOperation.ZoneConfiguration()
		options.previousServerChangeToken = CloudKitTokenStorage.getZoneToken(zoneId: zoneId, localDb: localDb)
		return options
	}
    
	private class func createFetchZoneChangesOperation(loadedRecords: [CKRecord], wrapper: ZonesToFetchWrapper, observer: AnyObserver<[CKRecord]>) -> CKFetchRecordZoneChangesOperation {
		var records: [CKRecord] = loadedRecords
		var moreComingFlag: Bool = false
		let optionsByRecordZoneID = wrapper.zoneIds.reduce(into: [CKRecordZone.ID: CKFetchRecordZoneChangesOperation.ZoneConfiguration](), { $0[$1] = zoneIdFetchOption(zoneId: $1, localDb: wrapper.localDb) })
		let operation = CKFetchRecordZoneChangesOperation(recordZoneIDs: wrapper.zoneIds, configurationsByRecordZoneID: optionsByRecordZoneID)
		operation.fetchAllChanges = true
		operation.recordChangedBlock = { record in
			records.append(record)
		}
		operation.recordZoneChangeTokensUpdatedBlock = {zoneId, token, data in
			CloudKitTokenStorage.setZoneToken(zoneId: zoneId, localDb: wrapper.localDb, token: token)
		}
		operation.recordZoneFetchCompletionBlock = { zoneId, changeToken, data, moreComing, error in
			if let error = error {
				switch CloudKitErrorType.errorType(forError: error) {
				case .tokenReset:
					CloudKitTokenStorage.setZoneToken(zoneId: zoneId, localDb: wrapper.localDb, token: nil)
				default:
					break
				}
				SwiftyBeaver.debug(error.localizedDescription)
			} else if let token = changeToken {
				CloudKitTokenStorage.setZoneToken(zoneId: zoneId, localDb: wrapper.localDb, token: token)
			}
			if moreComing {
				moreComingFlag = true
			}
		}
		operation.fetchRecordZoneChangesCompletionBlock = { error in
			if let error = error {
				SwiftyBeaver.debug(error.localizedDescription)
				switch CloudKitErrorType.errorType(forError: error) {
				case .retry(let timeout):
					DispatchQueue.main.asyncAfter(deadline: .now() + timeout) {
						CloudKitOperations.run(operation: createFetchZoneChangesOperation(loadedRecords: loadedRecords, wrapper: wrapper, observer: observer), localDb: wrapper.localDb)
					}
				case .tokenReset:
					CloudKitOperations.run(operation: createFetchZoneChangesOperation(loadedRecords: loadedRecords, wrapper: wrapper, observer: observer), localDb: wrapper.localDb)
				default:
					observer.onError(error)
				}
			} else {
				if moreComingFlag {
					CloudKitOperations.run(operation: createFetchZoneChangesOperation(loadedRecords: records, wrapper: wrapper, observer: observer), localDb: wrapper.localDb)
				} else {
					SwiftyBeaver.debug("\(records.count) updated records found")
					observer.onNext(records)
					observer.onCompleted()
				}
			}
		}
		return operation
	}
	
    class func fetchZoneChanges(wrapper: ZonesToFetchWrapper) -> Observable<[CKRecord]> {
        return Observable<[CKRecord]>.create { observer in
            if wrapper.zoneIds.count > 0 {
				CloudKitOperations.run(operation: createFetchZoneChangesOperation(loadedRecords: [], wrapper: wrapper, observer: observer), localDb: wrapper.localDb)
            } else {
                observer.onCompleted()
            }
            return Disposables.create()
        }
    }    
}
