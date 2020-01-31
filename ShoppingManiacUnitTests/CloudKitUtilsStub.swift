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

class CloudKitUtilsStub: CloudKitUtilsProtocol {
    
    private let operationsQueue = DispatchQueue(label: "CloudKitUtilsStub.operationsQueue", attributes: .concurrent)
    
    var onFetchRecords: (([CKRecord.ID], Bool) -> CKRecord)?
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
            guard let self = self else { fatalError() }
            self.operationsQueue.async { [weak self] in
                guard let self = self else { fatalError() }
                if let result = self.onFetchRecords?(recordIds, localDb) {
                    observer.onNext(result)
                    observer.onCompleted()
                } else {
                    observer.onError(CommonError(description: "No result"))
                }
            }
            return Disposables.create()
        }
    }
    
    func updateSubscriptions(subscriptions: [CKSubscription], localDb: Bool) -> Observable<Void> {
        return Observable<Void>.create {[weak self] observer in
            guard let self = self else { fatalError() }
            self.operationsQueue.async { [weak self] in
                guard let self = self else { fatalError() }
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
    
    func updateRecords(records: [CKRecord], localDb: Bool) -> Observable<Void> {
        return Observable<Void>.create {[weak self] observer in
            guard let self = self else { fatalError() }
            self.operationsQueue.async { [weak self] in
                guard let self = self else { fatalError() }
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
    
    func fetchDatabaseChanges(localDb: Bool) -> Observable<ZonesToFetchWrapper> {
        return Observable<ZonesToFetchWrapper>.create {[weak self] observer in
            guard let self = self else { fatalError() }
            self.operationsQueue.async { [weak self] in
                guard let self = self else { fatalError() }
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
    
    func fetchZoneChanges(wrapper: ZonesToFetchWrapper) -> Observable<[CKRecord]> {
        return Observable<[CKRecord]>.create {[weak self] observer in
            guard let self = self else { fatalError() }
            self.operationsQueue.async { [weak self] in
                guard let self = self else { fatalError() }
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
}
