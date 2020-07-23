//
//  CloudKitShoppingListItemsPublisher.swift
//  ShoppingManiac
//
//  Created by Dmitry Matyushkin on 7/23/20.
//  Copyright © 2020 Dmitry Matyushkin. All rights reserved.
//

import Combine
import CloudKit

struct CloudKitShoppingListItemsPublisher: Publisher {

	private final class CloudKitSubscription<S: Subscriber>: Subscription where S.Input == CKRecord, S.Failure == Error {

		@Autowired
		private var cloudKitUtils: CloudKitUtilsProtocol
		private let list: ShoppingList
		private var subscriber: S?
		private var cancellable: Cancellable?

		init(list: ShoppingList, subscriber: S) {
			self.list = list
			self.subscriber = subscriber
		}

		private func updateItemRecord(record: CKRecord, item: ShoppingListItem) -> CKRecord {
			record["comment"] = (item.comment ?? "") as CKRecordValue
			record["goodName"] = (item.good?.name ?? "") as CKRecordValue
			record["isWeight"] = item.isWeight as CKRecordValue
			record["price"] = item.price as CKRecordValue
			record["purchased"] = item.purchased as CKRecordValue
			record["quantity"] = item.quantity as CKRecordValue
			record["storeName"] = (item.store?.name ?? "") as CKRecordValue
			record["isRemoved"] = item.isRemoved as CKRecordValue
			record["isCrossListItem"] = item.isCrossListItem as CKRecordValue
			return record
		}

		func request(_ demand: Subscribers.Demand) {
			guard let subscriber = subscriber else { return }
			let items = list.listItems
            let locals = items.filter({$0.recordid == nil})
            let shares = items.filter({$0.recordid != nil}).reduce(into: [String: ShoppingListItem](), {result, item in
                if let recordId = item.recordid {
                    result[recordId] = item
                }
            })
            let listIsRemote = list.isRemote
			let recordZone = CKRecordZone(ownerName: list.ownerName).zoneID
            for local in locals {
                let recordName = CKRecord.ID().recordName
                let recordId = CKRecord.ID(recordName: recordName, zoneID: recordZone)
                let record = CKRecord(recordType: CloudKitUtils.itemRecordType, recordID: recordId)
                local.setRecordId(recordId: recordName)
				_ = subscriber.receive(self.updateItemRecord(record: record, item: local))
            }
            if shares.count > 0 {
				let publisher: AnyPublisher<CKRecord, Error> = self.cloudKitUtils.fetchRecords(recordIds: shares.keys.map({CKRecord.ID(recordName: $0, zoneID: recordZone)}), localDb: !listIsRemote).eraseToAnyPublisher()
				self.cancellable = publisher.sink(receiveCompletion: {completion in
					subscriber.receive(completion: completion)
				}, receiveValue: {record in
					if let item = shares[record.recordID.recordName] {
						_ = subscriber.receive(self.updateItemRecord(record: record, item: item))
					}
				})
            } else {
				subscriber.receive(completion: .finished)
            }
		}

		func cancel() {
			subscriber = nil
		}
	}

	private let list: ShoppingList

	init(list: ShoppingList) {
		self.list = list
	}

	func receive<S>(subscriber: S) where S: Subscriber, Self.Failure == S.Failure, Self.Output == S.Input {
		let subscription = CloudKitSubscription(list: list,
												subscriber: subscriber)
		subscriber.receive(subscription: subscription)
	}

	typealias Output = CKRecord
	typealias Failure = Error
}
