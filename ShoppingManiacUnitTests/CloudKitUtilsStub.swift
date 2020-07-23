//
//  CloudKitUtilsStub.swift
//  ShoppingManiacUnitTests
//
//  Created by Dmitry Matyushkin on 1/31/20.
//  Copyright © 2020 Dmitry Matyushkin. All rights reserved.
//

import Foundation
import RxSwift
import CloudKit
import SwiftyBeaver
import Combine

class CloudKitUtilsStub: CloudKitUtilsProtocol {
    
    static let operationsQueue = DispatchQueue(label: "CloudKitUtilsStub.operationsQueue", attributes: .concurrent)
    
    var onFetchRecords: (([CKRecord.ID], Bool) -> [CKRecord])?
    var onUpdateRecords: (([CKRecord], Bool) -> Void)?
    var onUpdateSubscriptions: (([CKSubscription], Bool) -> Void)?
    var onFetchDatabaseChanges: ((Bool) -> ZonesToFetchWrapper)?
    var onFetchZoneChanges: ((ZonesToFetchWrapper) -> [CKRecord])?
    
    func cleanup() {
        self.onFetchRecords = nil
        self.onUpdateRecords = nil
        self.onUpdateSubscriptions = nil
        self.onFetchDatabaseChanges = nil
        self.onFetchZoneChanges = nil
    }
    
    func fetchRecords(recordIds: [CKRecord.ID], localDb: Bool) -> Observable<CKRecord> {
        return Observable<CKRecord>.create {[weak self] observer in
            CloudKitUtilsStub.operationsQueue.async { [weak self] in
                guard let self = self else { fatalError() }
                SwiftyBeaver.debug("about to fetch records \(recordIds)")
                if let result = self.onFetchRecords?(recordIds, localDb) {
                    for record in result {
                        observer.onNext(record)
                    }
                    observer.onCompleted()
                } else {
                    observer.onError(CommonError(description: "No result"))
                }
            }
            return Disposables.create()
        }
    }

	func fetchRecords(recordIds: [CKRecord.ID], localDb: Bool) -> AnyPublisher<CKRecord, Error> {
		guard let onFetchRecords = self.onFetchRecords else { fatalError() }
		return FetchRecordsTestPublisher(recordIds: recordIds, localDb: localDb, onFetchRecords: onFetchRecords).eraseToAnyPublisher()
	}
    
    func updateSubscriptions(subscriptions: [CKSubscription], localDb: Bool) -> Observable<Void> {
        return Observable<Void>.create {[weak self] observer in
            CloudKitUtilsStub.operationsQueue.async { [weak self] in
                guard let self = self else { fatalError() }
                SwiftyBeaver.debug("about to update subscriptions \(subscriptions)")
                if let result = self.onUpdateSubscriptions?(subscriptions, localDb) {
                    observer.onNext(result)
                    observer.onCompleted()
                } else {
                    observer.onError(CommonError(description: "No result"))
                }
            }
            return Disposables.create()
        }
    }

	func updateSubscriptions(subscriptions: [CKSubscription], localDb: Bool) -> AnyPublisher<Void, Error> {
		guard let onUpdateSubscriptions = self.onUpdateSubscriptions else { fatalError() }
		return UpdateSubscriptionsTestPublisher(subscriptions: subscriptions, localDb: localDb, onUpdateSubscriptions: onUpdateSubscriptions).eraseToAnyPublisher()
	}
    
    func updateRecords(records: [CKRecord], localDb: Bool) -> Observable<Void> {
        return Observable<Void>.create {[weak self] observer in
            CloudKitUtilsStub.operationsQueue.async { [weak self] in
                guard let self = self else { fatalError() }
                SwiftyBeaver.debug("about to update records \(records)")
                if let result = self.onUpdateRecords?(records, localDb) {
                    observer.onNext(result)
                    observer.onCompleted()
                } else {
                    observer.onError(CommonError(description: "No result"))
                }
            }
            return Disposables.create()
        }
    }

	func updateRecords(records: [CKRecord], localDb: Bool) -> AnyPublisher<Void, Error> {
		guard let onUpdateRecords = self.onUpdateRecords else { fatalError() }
		return UpdateRecordsTestPublisher(records: records, localDb: localDb, onUpdateRecords: onUpdateRecords).eraseToAnyPublisher()
	}
    
    func fetchDatabaseChanges(localDb: Bool) -> Observable<ZonesToFetchWrapper> {
        return Observable<ZonesToFetchWrapper>.create {[weak self] observer in
            CloudKitUtilsStub.operationsQueue.async { [weak self] in
                guard let self = self else { fatalError() }
                SwiftyBeaver.debug("about to fetch database changes")
                if let result = self.onFetchDatabaseChanges?(localDb) {
                    observer.onNext(result)
                    observer.onCompleted()
                } else {
                    observer.onError(CommonError(description: "No result"))
                }
            }
            return Disposables.create()
        }
    }

	func fetchDatabaseChanges(localDb: Bool) -> AnyPublisher<ZonesToFetchWrapper, Error> {
		guard let onFetchDatabaseChanges = self.onFetchDatabaseChanges else { fatalError() }
		return FetchDatabaseChangesTestPublisher(localDb: localDb, onFetchDatabaseChanges: onFetchDatabaseChanges).eraseToAnyPublisher()
	}
    
    func fetchZoneChanges(wrapper: ZonesToFetchWrapper) -> Observable<[CKRecord]> {
        return Observable<[CKRecord]>.create {[weak self] observer in
            CloudKitUtilsStub.operationsQueue.async { [weak self] in
                guard let self = self else { fatalError() }
                SwiftyBeaver.debug("about to fetch zone changes \(wrapper.zoneIds)")
                if let result = self.onFetchZoneChanges?(wrapper) {
                    observer.onNext(result)
                    observer.onCompleted()
                } else {
                    observer.onError(CommonError(description: "No result"))
                }
            }
            return Disposables.create()
        }
    }

	func fetchZoneChanges(wrapper: ZonesToFetchWrapper) -> AnyPublisher<[CKRecord], Error> {
		guard let onFetchZoneChanges = self.onFetchZoneChanges else { fatalError() }
		return FetchZoneChangesTestPublisher(wrapper: wrapper, onFetchZoneChanges: onFetchZoneChanges).eraseToAnyPublisher()
	}
}
