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
						CKContainer.default().database(localDb: localDb).add(createFetchRecordsOperation(recordIds: recordIds, localDb: localDb, observer: observer))
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
            CKContainer.default().database(localDb: localDb).add(createFetchRecordsOperation(recordIds: recordIds, localDb: localDb, observer: observer))
            return Disposables.create()
        }
    }
    
    class func deleteRecords(recordIds: [CKRecord.ID], localDb: Bool) -> Observable<Void> {
        return Observable<Void>.create { observer in
            let modifyOperation = CKModifyRecordsOperation(recordsToSave: nil, recordIDsToDelete: recordIds)
            modifyOperation.savePolicy = .allKeys
            modifyOperation.perRecordCompletionBlock = {record, error in
                if let error = error {
                    SwiftyBeaver.debug("Error while deleting records \(error.localizedDescription)")
                } else {
                    SwiftyBeaver.debug("Successfully deleted record \(record.recordID.recordName)")
                }
            }
            modifyOperation.modifyRecordsCompletionBlock = { records, recordIds, error in
                if let error = error {
                    SwiftyBeaver.debug("Error when deleting records \(error.localizedDescription)")
                }
                observer.onCompleted()
            }
            CKContainer.default().database(localDb: localDb).add(modifyOperation)
            
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
            CKContainer.default().database(localDb: localDb).add(operation)
            
            return Disposables.create()
        }
    }
    
    class func fetchRecordsQuery(recordType: String, localDb: Bool) -> Observable<[CKRecord]> {
        return Observable<[CKRecord]>.create { observer in
            let query = CKQuery(recordType: recordType, predicate: NSPredicate(value: true))
            let recordZone = CKRecordZone(zoneName: CloudKitUtils.zoneName)
            CKContainer.default().database(localDb: localDb).perform(query, inZoneWith: recordZone.zoneID, completionHandler: { (records, error) in
                if let records = records, error == nil {
                    SwiftyBeaver.debug("\(records.count) list records found")
                    observer.onNext(records)
                    observer.onCompleted()
                } else {
                    SwiftyBeaver.debug("no list records found")
                    observer.onCompleted()
                }
            })
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
						CKContainer.default().database(localDb: localDb).add(createUpdateRecordsOperation(records: records, localDb: localDb, observer: observer))
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
            CKContainer.default().database(localDb: localDb).add(createUpdateRecordsOperation(records: records, localDb: localDb, observer: observer))
            return Disposables.create()
        }
    }
	
	private class func createFetchDatabaseChangesOperation(loadedZoneIds: [CKRecordZone.ID], localDb: Bool, observer: AnyObserver<ZonesToFetchWrapper>) -> CKFetchDatabaseChangesOperation {
		let operation = CKFetchDatabaseChangesOperation(previousServerChangeToken: localDb ? UserDefaults.standard.localServerChangeToken : UserDefaults.standard.sharedServerChangeToken)
		operation.fetchAllChanges = true
		var zoneIds: [CKRecordZone.ID] = loadedZoneIds
		operation.recordZoneWithIDChangedBlock = { zoneId in
			zoneIds.append(zoneId)
		}
		operation.changeTokenUpdatedBlock = { token in
			setToken(localDb: localDb, token: token)
		}
		operation.qualityOfService = .utility
		operation.fetchAllChanges = true
		operation.fetchDatabaseChangesCompletionBlock = { token, moreComing, error in
			if let error = error {
				SwiftyBeaver.debug(error.localizedDescription)
				switch CloudKitErrorType.errorType(forError: error) {
				case .retry(let timeout):
					DispatchQueue.main.asyncAfter(deadline: .now() + timeout) {
						CKContainer.default().database(localDb: localDb).add(createFetchDatabaseChangesOperation(loadedZoneIds: loadedZoneIds, localDb: localDb, observer: observer))
					}
				case .tokenReset:
					clearToken(localDb: localDb)
					CKContainer.default().database(localDb: localDb).add(createFetchDatabaseChangesOperation(loadedZoneIds: loadedZoneIds, localDb: localDb, observer: observer))
				default:
					clearToken(localDb: localDb)
					observer.onError(error)
				}
			} else if let token = token {
				setToken(localDb: localDb, token: token)
				if moreComing {
					CKContainer.default().database(localDb: localDb).add(createFetchDatabaseChangesOperation(loadedZoneIds: zoneIds, localDb: localDb, observer: observer))
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
            CKContainer.default().database(localDb: localDb).add(createFetchDatabaseChangesOperation(loadedZoneIds: [], localDb: localDb, observer: observer))
            return Disposables.create()
        }
    }
    
    private class func clearToken(localDb: Bool) {
        if localDb {
            UserDefaults.standard.localServerChangeToken = nil
        } else {
            UserDefaults.standard.sharedServerChangeToken = nil
        }
    }
    
	private class func setToken(localDb: Bool, token: CKServerChangeToken) {
        if localDb {
            UserDefaults.standard.localServerChangeToken = token
        } else {
            UserDefaults.standard.sharedServerChangeToken = token
        }
    }
    
	private class func createFetchZoneChangesOperation(loadedRecords: [CKRecord], wrapper: ZonesToFetchWrapper, observer: AnyObserver<[CKRecord]>) -> CKFetchRecordZoneChangesOperation {
		var records: [CKRecord] = loadedRecords
		var moreComingFlag: Bool = false
		var optionsByRecordZoneID = [CKRecordZone.ID: CKFetchRecordZoneChangesOperation.ZoneConfiguration]()
		for zoneId in wrapper.zoneIds {
			let options = CKFetchRecordZoneChangesOperation.ZoneConfiguration()
			options.previousServerChangeToken = UserDefaults.standard.getZoneChangedToken(zoneName: zoneId.zoneName + (wrapper.localDb ? "local" : "remote"))
			optionsByRecordZoneID[zoneId] = options
		}
		let operation = CKFetchRecordZoneChangesOperation(recordZoneIDs: wrapper.zoneIds, configurationsByRecordZoneID: optionsByRecordZoneID)
		operation.fetchAllChanges = true
		operation.recordChangedBlock = { record in
			records.append(record)
		}
		operation.recordZoneChangeTokensUpdatedBlock = {zoneId, token, data in
			UserDefaults.standard.setZoneChangeToken(zoneName: zoneId.zoneName + (wrapper.localDb ? "local" : "remote"), token: token)
		}
		operation.recordZoneFetchCompletionBlock = { zoneId, changeToken, data, moreComing, error in
			if let error = error {
				switch CloudKitErrorType.errorType(forError: error) {
				case .tokenReset:
					UserDefaults.standard.setZoneChangeToken(zoneName: zoneId.zoneName + (wrapper.localDb ? "local" : "remote"), token: nil)
				default:
					break
				}
				SwiftyBeaver.debug(error.localizedDescription)
			} else if let token = changeToken {
				UserDefaults.standard.setZoneChangeToken(zoneName: zoneId.zoneName + (wrapper.localDb ? "local" : "remote"), token: token)
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
						CKContainer.default().database(localDb: wrapper.localDb).add(createFetchZoneChangesOperation(loadedRecords: loadedRecords, wrapper: wrapper, observer: observer))
					}
				case .tokenReset:
					CKContainer.default().database(localDb: wrapper.localDb).add(createFetchZoneChangesOperation(loadedRecords: loadedRecords, wrapper: wrapper, observer: observer))
				default:
					observer.onError(error)
				}
			} else {
				if moreComingFlag {
					CKContainer.default().database(localDb: wrapper.localDb).add(createFetchZoneChangesOperation(loadedRecords: records, wrapper: wrapper, observer: observer))
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
				CKContainer.default().database(localDb: wrapper.localDb).add(createFetchZoneChangesOperation(loadedRecords: [], wrapper: wrapper, observer: observer))
            } else {
                observer.onCompleted()
            }
            return Disposables.create()
        }
    }    
}
