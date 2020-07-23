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
import Combine

protocol CloudKitUtilsProtocol {
	func fetchRecords(recordIds: [CKRecord.ID], localDb: Bool) -> AnyPublisher<CKRecord, Error>
	func updateSubscriptions(subscriptions: [CKSubscription], localDb: Bool) -> AnyPublisher<Void, Error>
	func updateRecords(records: [CKRecord], localDb: Bool) -> AnyPublisher<Void, Error>
	func fetchDatabaseChanges(localDb: Bool) -> AnyPublisher<ZonesToFetchWrapper, Error>
	func fetchZoneChanges(wrapper: ZonesToFetchWrapper) -> AnyPublisher<[CKRecord], Error>
}

class CloudKitUtils: CloudKitUtilsProtocol, DIDependency {
    
    static let retryQueue = DispatchQueue(label: "CloudKitUtils.retryQueue", attributes: .concurrent)
    
    static let zoneName = "ShareZone"
    static let listRecordType = "ShoppingList"
    static let itemRecordType = "ShoppingListItem"

	required init() {}

	func fetchRecords(recordIds: [CKRecord.ID], localDb: Bool) -> AnyPublisher<CKRecord, Error> {
		return CloudKitFetchRecordsPublisher(recordIds: recordIds, localDb: localDb).eraseToAnyPublisher()
	}

	func updateSubscriptions(subscriptions: [CKSubscription], localDb: Bool) -> AnyPublisher<Void, Error> {
		return CloudKitUpdateSubscriptionsPublisher(subscriptions: subscriptions, localDb: localDb).eraseToAnyPublisher()
	}

	func updateRecords(records: [CKRecord], localDb: Bool) -> AnyPublisher<Void, Error> {
		return CloudKitUpdateRecordsPublisher(records: records, localDb: localDb).eraseToAnyPublisher()
	}

	func fetchDatabaseChanges(localDb: Bool) -> AnyPublisher<ZonesToFetchWrapper, Error> {
		return CloudKitFetchDatabaseChangesPublisher(localDb: localDb).eraseToAnyPublisher()
	}

	func fetchZoneChanges(wrapper: ZonesToFetchWrapper) -> AnyPublisher<[CKRecord], Error> {
		return CloudKitFetchZoneChangesPublisher(wrapper: wrapper).eraseToAnyPublisher()
	}
}
