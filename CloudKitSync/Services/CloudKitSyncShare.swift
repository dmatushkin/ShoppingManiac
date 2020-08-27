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

protocol CloudKitSyncShareProtocol {
	func setupUserPermissions(itemType: CloudKitSyncItemProtocol.Type) -> AnyPublisher<Void, Error>
	func shareItem(item: CloudKitSyncItemProtocol, shareTitle: String, shareType: String) -> AnyPublisher<CKShare, Error>
	func updateItem(item: CloudKitSyncItemProtocol) -> AnyPublisher<Void, Error>
}

final class CloudKitSyncShare: CloudKitSyncShareProtocol, DIDependency {

	@Autowired
	private var cloudKitUtils: CloudKitSyncUtilsProtocol

	init() { }

	func setupUserPermissions(itemType: CloudKitSyncItemProtocol.Type) -> AnyPublisher<Void, Error> {
		return Future { promise in
			CKContainer.default().accountStatus { (status, error) in
				if let error = error {
					promise(.failure(error))
				} else if status == .available {
					CKContainer.default().status(forApplicationPermission: .userDiscoverability, completionHandler: { (status, error) in
						if let error = error {
							promise(.failure(error))
						} else if status == .granted {
							let recordZone = CKRecordZone(zoneName: itemType.zoneName)
							CKContainer.default().privateCloudDatabase.save(recordZone) { (_, error) in
								if let error = error {
									promise(.failure(error))
								} else {
									promise(.success(()))
								}
							}
						} else if status == .initialState {
							CKContainer.default().requestApplicationPermission(.userDiscoverability, completionHandler: { (status, error) in
								if let error = error {
									promise(.failure(error))
								} else if status == .granted {
									let recordZone = CKRecordZone(zoneName: itemType.zoneName)
									CKContainer.default().privateCloudDatabase.save(recordZone) { (_, error) in
										if let error = error {
											promise(.failure(error))
										} else {
											promise(.success(()))
										}
									}
								} else {
									promise(.failure(CommonError(description: "CloudKit discoverability status incorrect") as Error))
								}
							})
						} else {
							promise(.failure(CommonError(description: "CloudKit discoverability status incorrect") as Error))
						}
					})
				} else {
					promise(.failure(CommonError(description: "CloudKit account status incorrect") as Error))
				}
			}
		}.eraseToAnyPublisher()
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
				.eraseToAnyPublisher()
		} else {
			let recordName = CKRecord.ID().recordName
			let recordId = CKRecord.ID(recordName: recordName, zoneID: recordZoneID)
			let record = CKRecord(recordType: type(of: item).recordType, recordID: recordId)
			return item.setRecordId(recordName)
				.map({ _ in record})
				.eraseToAnyPublisher()
		}
	}

	private func updateDependentRecords(rootItem: CloudKitSyncItemProtocol, rootRecord: CKRecord) -> AnyPublisher<[CKRecord], Error> {
		if !type(of: rootItem).hasDependentItems || rootItem.dependentItems().count == 0 {
			return Future { promise in
				return promise(.success([]))
			}.eraseToAnyPublisher()
		}
		let recordZoneID = CKRecordZone(ownerName: rootItem.ownerName, zoneName: type(of: rootItem).zoneName).zoneID
		let localItems = Publishers.Sequence<[CloudKitSyncItemProtocol], Error>(sequence: rootItem.dependentItems().filter({ $0.recordId == nil }))
			.flatMap({ item -> AnyPublisher<(CloudKitSyncItemProtocol, CKRecord), Error> in
				let recordName = CKRecord.ID().recordName
				let recordId = CKRecord.ID(recordName: recordName, zoneID: recordZoneID)
				let record = CKRecord(recordType: type(of: item).recordType, recordID: recordId)
				record.setParent(rootRecord)
				return item.setRecordId(recordName).map({_ in
					item.populate(record: record)
					return (item, record)
				}).eraseToAnyPublisher()
			}).eraseToAnyPublisher()
		let remoteItemsMap = rootItem.dependentItems().filter({ $0.recordId != nil }).reduce(into: [String: CloudKitSyncItemProtocol](), {result, item in
			if let recordId = item.recordId {
				result[recordId] = item
			}
		})
		let remoteRecordIds = rootItem.dependentItems().compactMap({ $0.recordId }).map({ CKRecord.ID(recordName: $0, zoneID: recordZoneID) })
		let remoteItems = self.cloudKitUtils.fetchRecords(recordIds: remoteRecordIds, localDb: !rootItem.isRemote)
			.compactMap({ record -> (CloudKitSyncItemProtocol, CKRecord)? in
				if let item = remoteItemsMap[record.recordID.recordName] {
					item.populate(record: record)
					return (item, record)
				} else {
					return nil
				}
			}).eraseToAnyPublisher()
		return localItems.merge(with: remoteItems).collect().flatMap({tuples -> AnyPublisher<[CKRecord], Error> in
				let records = tuples.map({ $0.1 })
				rootRecord[type(of: rootItem).dependentItemsRecordAttribute] = records.map({ CKRecord.Reference(record: $0, action: .deleteSelf) }) as CKRecordValue
				return Publishers.Sequence(sequence: tuples).flatMap({[unowned self] tuple in
					self.updateDependentRecords(rootItem: tuple.0, rootRecord: tuple.1)
				}).collect().map({ allData -> [CKRecord] in
					return records + allData.flatMap({ $0 })
				}).eraseToAnyPublisher()
			}).eraseToAnyPublisher()
	}

	func shareItem(item: CloudKitSyncItemProtocol, shareTitle: String, shareType: String) -> AnyPublisher<CKShare, Error> {
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

	func updateItem(item: CloudKitSyncItemProtocol) -> AnyPublisher<Void, Error> {
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
