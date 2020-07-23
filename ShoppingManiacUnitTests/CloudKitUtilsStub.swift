//
//  CloudKitUtilsStub.swift
//  ShoppingManiacUnitTests
//
//  Created by Dmitry Matyushkin on 1/31/20.
//  Copyright © 2020 Dmitry Matyushkin. All rights reserved.
//

import Foundation
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
    
	func fetchRecords(recordIds: [CKRecord.ID], localDb: Bool) -> AnyPublisher<CKRecord, Error> {
		guard let onFetchRecords = self.onFetchRecords else { fatalError() }
		return FetchRecordsTestPublisher(recordIds: recordIds, localDb: localDb, onFetchRecords: onFetchRecords).eraseToAnyPublisher()
	}

	func updateSubscriptions(subscriptions: [CKSubscription], localDb: Bool) -> AnyPublisher<Void, Error> {
		guard let onUpdateSubscriptions = self.onUpdateSubscriptions else { fatalError() }
		return UpdateSubscriptionsTestPublisher(subscriptions: subscriptions, localDb: localDb, onUpdateSubscriptions: onUpdateSubscriptions).eraseToAnyPublisher()
	}
    
	func updateRecords(records: [CKRecord], localDb: Bool) -> AnyPublisher<Void, Error> {
		guard let onUpdateRecords = self.onUpdateRecords else { fatalError() }
		return UpdateRecordsTestPublisher(records: records, localDb: localDb, onUpdateRecords: onUpdateRecords).eraseToAnyPublisher()
	}

	func fetchDatabaseChanges(localDb: Bool) -> AnyPublisher<ZonesToFetchWrapper, Error> {
		guard let onFetchDatabaseChanges = self.onFetchDatabaseChanges else { fatalError() }
		return FetchDatabaseChangesTestPublisher(localDb: localDb, onFetchDatabaseChanges: onFetchDatabaseChanges).eraseToAnyPublisher()
	}

	func fetchZoneChanges(wrapper: ZonesToFetchWrapper) -> AnyPublisher<[CKRecord], Error> {
		guard let onFetchZoneChanges = self.onFetchZoneChanges else { fatalError() }
		return FetchZoneChangesTestPublisher(wrapper: wrapper, onFetchZoneChanges: onFetchZoneChanges).eraseToAnyPublisher()
	}
}
