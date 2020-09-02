//
//  CloudKitSyncLoader.swift
//  CloudKitSync
//
//  Created by Dmitry Matyushkin on 8/26/20.
//  Copyright © 2020 Dmitry Matyushkin. All rights reserved.
//

import Foundation
import CloudKit
import DependencyInjection
import Combine
import CommonError

public protocol CloudKitSyncLoaderProtocol {

	func loadShare<T>(metadata: CKShare.Metadata, itemType: T.Type) -> AnyPublisher<T, Error> where T: CloudKitSyncItemProtocol
	func fetchChanges<T>(localDb: Bool, itemType: T.Type) -> AnyPublisher<[T], Error> where T: CloudKitSyncItemProtocol
}

public final class CloudKitSyncLoader: CloudKitSyncLoaderProtocol, DIDependency {

	@Autowired
    private var cloudKitUtils: CloudKitSyncUtilsProtocol

	public init() { }

	public func loadShare<T>(metadata: CKShare.Metadata, itemType: T.Type) -> AnyPublisher<T, Error> where T: CloudKitSyncItemProtocol {
		return self.cloudKitUtils.fetchRecords(recordIds: [metadata.rootRecordID], localDb: false)
			.flatMap({[unowned self] record in
				self.storeRecord(record: record, itemType: itemType)
			}).flatMap({ item in
				item.mapTo(type: T.self)
			}).eraseToAnyPublisher()
	}

	private func storeRecord(record: CKRecord, itemType: CloudKitSyncItemProtocol.Type) -> AnyPublisher<CloudKitSyncItemProtocol, Error> {
		if itemType.hasDependentItems {
			let dependentRecordIDs = (record[itemType.dependentItemsRecordAttribute] as? [CKRecord.Reference])?.map({ $0.recordID }) ?? []
			return self.cloudKitUtils.fetchRecords(recordIds: dependentRecordIDs, localDb: false).flatMap({[unowned self] dependentRecord in
				self.storeRecord(record: dependentRecord, itemType: itemType.dependentItemsType.self)
				}).collect().map({items in itemType.store(record: record, isRemote: true, dependentItems: items)}).eraseToAnyPublisher()
		} else {
			return Future { promise in
				return promise(.success(itemType.store(record: record, isRemote: true, dependentItems: [])))
			}.eraseToAnyPublisher()
		}
	}

	public func fetchChanges<T>(localDb: Bool, itemType: T.Type) -> AnyPublisher<[T], Error> where T: CloudKitSyncItemProtocol {
		return self.cloudKitUtils.fetchDatabaseChanges(localDb: localDb)
			.flatMap({[unowned self] zoneIds in
			self.cloudKitUtils.fetchZoneChanges(zoneIds: zoneIds, localDb: localDb)
			}).map({[unowned self] records in
				return self.processChangesRecords(records: records, itemType: itemType, parent: nil, localDb: localDb)
			}).flatMap({values in
				return Future { promise in
					if let result = values as? [T] {
						return promise(.success(result))
					} else {
						return promise(.failure(CommonError(description: "Unable to map list") as Error))
					}
				}
			}).eraseToAnyPublisher()
	}

	private func processChangesRecords(records: [CKRecord], itemType: CloudKitSyncItemProtocol.Type, parent: CKRecord?, localDb: Bool) -> [CloudKitSyncItemProtocol] {
		let itemRecords = records.filter({ $0.recordType == itemType.recordType && (parent == nil || $0.parent?.recordID.recordName == parent?.recordID.recordName) })
		if itemType.hasDependentItems {
			return itemRecords.map({itemType.store(record: $0, isRemote: !localDb, dependentItems: processChangesRecords(records: records, itemType: itemType.dependentItemsType, parent: $0, localDb: localDb))})
		} else {
			return itemRecords.map({itemType.store(record: $0, isRemote: !localDb, dependentItems: [])})
		}
	}
}
