//
//  CloudKitSyncShare.swift
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

extension CKRecordZone {

	convenience init(ownerName: String?, zoneName: String) {
		if let ownerName = ownerName {
			self.init(zoneID: CKRecordZone.ID(zoneName: zoneName, ownerName: ownerName))
		} else {
			self.init(zoneName: zoneName)
		}
	}
}

public protocol CloudKitSyncShareProtocol {
	func setupUserPermissions(itemType: CloudKitSyncItemProtocol.Type) -> AnyPublisher<Void, Error>
	func shareItem(item: CloudKitSyncItemProtocol, shareTitle: String, shareType: String) -> AnyPublisher<CKShare, Error>
	func updateItem(item: CloudKitSyncItemProtocol) -> AnyPublisher<Void, Error>
}

public final class CloudKitSyncShare: CloudKitSyncShareProtocol, DIDependency {

	@Autowired
	private var cloudKitUtils: CloudKitSyncUtilsProtocol

	public init() { }

	private func processAccountStatus(status: CKAccountStatus) -> AnyPublisher<CKContainer_Application_PermissionStatus, Error> {
		switch status {
		case .couldNotDetermine:
			return Future { promise in
				return promise(.failure(CommonError(description: "CloudKit account status incorrect") as Error))
			}.eraseToAnyPublisher()
		case .available:
			return CloudKitPermissionStatusPublisher(permission: .userDiscoverability).eraseToAnyPublisher()
		case .restricted:
			return Future { promise in
				return promise(.failure(CommonError(description: "CloudKit account is restricted") as Error))
			}.eraseToAnyPublisher()
		case .noAccount:
			return Future { promise in
				return promise(.failure(CommonError(description: "CloudKit account does not exist") as Error))
			}.eraseToAnyPublisher()
		@unknown default:
			return Future { promise in
				return promise(.failure(CommonError(description: "CloudKit account status unknown") as Error))
			}.eraseToAnyPublisher()
		}
	}

	private func processPermissionStatus(status: CKContainer_Application_PermissionStatus, itemType: CloudKitSyncItemProtocol.Type) -> AnyPublisher<Void, Error> {
		switch status {
		case .initialState:
			return CloudKitRequestPermissionPublisher(permission: .userDiscoverability)
				.flatMap({[unowned self] status in self.processPermissionStatus(status: status, itemType: itemType) })
				.eraseToAnyPublisher()
		case .couldNotComplete:
			return Future { promise in
				return promise(.failure(CommonError(description: "CloudKit permission status could not complete") as Error))
			}.eraseToAnyPublisher()
		case .denied:
			return Future { promise in
				return promise(.failure(CommonError(description: "CloudKit permission status denied") as Error))
			}.eraseToAnyPublisher()
		case .granted:
			let recordZone = CKRecordZone(zoneName: itemType.zoneName)
			return CloudKitSaveZonePublisher(zone: recordZone).eraseToAnyPublisher()
		@unknown default:
			return Future { promise in
				return promise(.failure(CommonError(description: "CloudKit account status unknown") as Error))
			}.eraseToAnyPublisher()
		}
	}

	public func setupUserPermissions(itemType: CloudKitSyncItemProtocol.Type) -> AnyPublisher<Void, Error> {
		return CloudKitAccountStatusPublisher().flatMap({[unowned self] accountStatus -> AnyPublisher<CKContainer_Application_PermissionStatus, Error> in
			self.processAccountStatus(status: accountStatus)
			}).flatMap({[unowned self] permissionStatus -> AnyPublisher<Void, Error> in
				self.processPermissionStatus(status: permissionStatus, itemType: itemType)
			}).eraseToAnyPublisher()
	}

	private func setItemParents(item: CloudKitSyncItemProtocol) -> AnyPublisher<CloudKitSyncItemProtocol, Error> {
		let items = item.dependentItems()
		return Publishers.Sequence(sequence: items)
			.flatMap({ $0.setParent(item: item) })
			.flatMap({[unowned self] item -> AnyPublisher<CloudKitSyncItemProtocol, Error> in
				if type(of: item).hasDependentItems {
					return self.setItemParents(item: item)
				} else {
					return Future { promise in
						return promise(.success(item))
					}.eraseToAnyPublisher()
				}
			}).collect()
			.map({ _ in item })
			.eraseToAnyPublisher()
	}

	private func updateItemRecordId(item: CloudKitSyncItemProtocol) -> AnyPublisher<CKRecord, Error> {
		let recordZoneID = CKRecordZone(ownerName: item.ownerName, zoneName: type(of: item).zoneName).zoneID
		if let recordName = item.recordId {
			let recordId = CKRecord.ID(recordName: recordName, zoneID: recordZoneID)
			return cloudKitUtils.fetchRecords(recordIds: [recordId], localDb: !item.isRemote)
				.flatMap({ record in
				return item.populate(record: record)
			}).eraseToAnyPublisher()
		} else {
			let recordName = CKRecord.ID().recordName
			let recordId = CKRecord.ID(recordName: recordName, zoneID: recordZoneID)
			let record = CKRecord(recordType: type(of: item).recordType, recordID: recordId)
			return item.setRecordId(recordName).flatMap({item in
				item.populate(record: record)
			}).eraseToAnyPublisher()
		}
	}

	private func fetchRemoteRecords(rootItem: CloudKitSyncItemProtocol, rootRecord: CKRecord, recordZoneID: CKRecordZone.ID) -> AnyPublisher<(CloudKitSyncItemProtocol, CKRecord), Error> {
		let remoteRecordIds = rootItem.dependentItems().compactMap({ $0.recordId }).map({ CKRecord.ID(recordName: $0, zoneID: recordZoneID) })
		if remoteRecordIds.count == 0 {
			return Empty(completeImmediately: true, outputType: (CloudKitSyncItemProtocol, CKRecord).self, failureType: Error.self).eraseToAnyPublisher()
		}
		let remoteItemsMap = rootItem.dependentItems().filter({ $0.recordId != nil }).reduce(into: [String: CloudKitSyncItemProtocol](), {result, item in
			if let recordId = item.recordId {
				result[recordId] = item
			}
		})
		return self.cloudKitUtils.fetchRecords(recordIds: remoteRecordIds, localDb: !rootItem.isRemote)
		.flatMap({ record -> AnyPublisher<(CloudKitSyncItemProtocol, CKRecord), Error> in
			if let item = remoteItemsMap[record.recordID.recordName] {
				record.setParent(rootRecord)
				return item.populate(record: record).map({(item, $0)}).eraseToAnyPublisher()
			} else {
				return Future { promise in
					promise(.failure(CommonError(description: "Consistency error") as Error))
				}.eraseToAnyPublisher()
			}
		}).eraseToAnyPublisher()
	}

	private func updateDependentRecords(rootItem: CloudKitSyncItemProtocol, rootRecord: CKRecord) -> AnyPublisher<[CKRecord], Error> {
		if !type(of: rootItem).hasDependentItems || rootItem.dependentItems().count == 0 {
			return Future { promise in
				return promise(.success([]))
			}.eraseToAnyPublisher()
		}
		let recordZoneID = CKRecordZone(ownerName: rootItem.ownerName, zoneName: type(of: rootItem).zoneName).zoneID
		let remoteItems = self.fetchRemoteRecords(rootItem: rootItem, rootRecord: rootRecord, recordZoneID: recordZoneID)
		let localItems = Publishers.Sequence<[CloudKitSyncItemProtocol], Error>(sequence: rootItem.dependentItems().filter({ $0.recordId == nil }))
			.flatMap({ item -> AnyPublisher<(CloudKitSyncItemProtocol, CKRecord), Error> in
				let recordName = CKRecord.ID().recordName
				let recordId = CKRecord.ID(recordName: recordName, zoneID: recordZoneID)
				let record = CKRecord(recordType: type(of: item).recordType, recordID: recordId)
				record.setParent(rootRecord)
				return item.setRecordId(recordName).flatMap({item in
					item.populate(record: record).map({(item, $0)})
				}).eraseToAnyPublisher()
			}).eraseToAnyPublisher()
		return Publishers.Concatenate(prefix: remoteItems, suffix: localItems).collect().flatMap({tuples -> AnyPublisher<[CKRecord], Error> in
				let records = tuples.map({ $0.1 })
				rootRecord[type(of: rootItem).dependentItemsRecordAttribute] = records.map({ CKRecord.Reference(record: $0, action: .deleteSelf) }) as CKRecordValue
				return Publishers.Sequence(sequence: tuples).flatMap({[unowned self] tuple in
					self.updateDependentRecords(rootItem: tuple.0, rootRecord: tuple.1)
				}).collect().map({ allData -> [CKRecord] in
					return records + allData.flatMap({ $0 })
				}).eraseToAnyPublisher()
			}).eraseToAnyPublisher()
	}

	public func shareItem(item: CloudKitSyncItemProtocol, shareTitle: String, shareType: String) -> AnyPublisher<CKShare, Error> {
		self.setItemParents(item: item).flatMap({[unowned self] updatedItem in
			self.updateItemRecordId(item: updatedItem)
		}).flatMap({[unowned self] record in
			return self.updateDependentRecords(rootItem: item, rootRecord: record).flatMap({[unowned self] records -> AnyPublisher<CKShare, Error> in
				let share = CKShare(rootRecord: record)
				share[CKShare.SystemFieldKey.title] = shareTitle as CKRecordValue
				share[CKShare.SystemFieldKey.shareType] = shareType as CKRecordValue
				share.publicPermission = .readWrite

				return self.cloudKitUtils.updateRecords(records: [record, share], localDb: !item.isRemote)
					.flatMap({[unowned self] _ in
						self.cloudKitUtils.updateRecords(records: records, localDb: !item.isRemote)
					}).map({_ in share}).eraseToAnyPublisher()
			}).eraseToAnyPublisher()
		}).eraseToAnyPublisher()
	}

	public func updateItem(item: CloudKitSyncItemProtocol) -> AnyPublisher<Void, Error> {
		self.setItemParents(item: item).flatMap({[unowned self] updatedItem in
			self.updateItemRecordId(item: updatedItem)
		}).flatMap({[unowned self] record -> AnyPublisher<(CKRecord, CKRecord?), Error> in
			if let share = record.share {
				return self.cloudKitUtils.fetchRecords(recordIds: [share.recordID], localDb: !item.isRemote).map({share in
					return (record, share)
				}).eraseToAnyPublisher()
			} else {
				return Future { promise in
					return promise(.success((record, nil)))
				}.eraseToAnyPublisher()
			}
		}).flatMap({[unowned self] (record, share) in
			return self.updateDependentRecords(rootItem: item, rootRecord: record)
				.flatMap({[unowned self] records -> AnyPublisher<Void, Error> in
					return self.cloudKitUtils.updateRecords(records: [record, share].compactMap({$0}), localDb: !item.isRemote)
						.flatMap({[unowned self] _ in
							self.cloudKitUtils.updateRecords(records: records, localDb: !item.isRemote)
						}).map({_ in ()}).eraseToAnyPublisher()
				}).eraseToAnyPublisher()
		}).eraseToAnyPublisher()
	}
}
