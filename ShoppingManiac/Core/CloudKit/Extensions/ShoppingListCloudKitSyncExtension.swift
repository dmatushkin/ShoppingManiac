//
//  ShoppingListCloudKitSyncExtension.swift
//  ShoppingManiac
//
//  Created by Dmitry Matyushkin on 8/27/20.
//  Copyright © 2020 Dmitry Matyushkin. All rights reserved.
//

import Foundation
import CoreData
import CloudKitSync
import CloudKit
import CoreStore
import Combine
import CommonError

extension ShoppingList {

	func toModel() -> AnyPublisher<CloudKitShoppingList, Error> {
		return CoreDataOperationPublisher(operation: {[weak self] transaction in
			guard let self = self, let origList = transaction.fetchExisting(self) else { throw (CommonError(description: "Shopping list unexpectedly released") as Error) }
			let list = CloudKitShoppingList()
			list.objectID = origList.objectID
			list.name = origList.name
			list.date = Date(timeIntervalSinceReferenceDate: origList.date)
			list.isRemoved = origList.isRemoved
			list.isRemote = origList.isRemote
			list.ownerName = origList.ownerName
			list.recordId = origList.recordid
			let items = try transaction.fetchAll(origList.itemsFetchBuilder.orderBy(.descending(\.good?.name)))
			list.items = items.map({origItem -> CloudKitShoppingItem in
				let item = CloudKitShoppingItem()
				item.objectID = origItem.objectID
				item.recordId = origItem.recordid
				item.ownerName = origList.ownerName
				item.isRemote = origList.isRemote
				item.comment = origItem.comment
				item.goodName = origItem.good?.name
				item.storeName = origItem.store?.name
				item.isWeight = origItem.isWeight
				item.price = Double(origItem.price)
				item.quantity = Int(origItem.quantity)
				item.isPurchased = origItem.purchased
				item.isRemoved = origItem.isRemoved
				item.isCrossListItem = origItem.isCrossListItem
				return item
			})
			return list
		}).eraseToAnyPublisher()
	}

	class func storeModel(model: CloudKitShoppingList) -> AnyPublisher<ShoppingList, Error> {
		return CoreDataOperationPublisher(operation: { transaction in
			let list = model.objectID.flatMap({ transaction.fetchExisting($0) }) ?? transaction.create(Into<ShoppingList>())
			list.name = model.name
			list.date = model.date.timeIntervalSinceReferenceDate
			list.isRemoved = model.isRemoved
			list.isRemote = model.isRemote
			list.ownerName = model.ownerName
			list.recordid = model.recordId
			let items = try model.items.map({ origItem throws -> ShoppingListItem in
				let item = origItem.objectID.flatMap({ transaction.fetchExisting($0) }) ?? transaction.create(Into<ShoppingListItem>())
				if let name = origItem.goodName, !name.isEmpty {
					let good = try transaction.fetchOne(From<Good>().where(Where("name == %@", name))) ?? transaction.create(Into<Good>())
					good.name = name
					item.good = good
				} else {
					item.good = nil
				}
				if let storeName = origItem.storeName, !storeName.isEmpty {
					let store = try transaction.fetchOne(From<Store>().where(Where("name == %@", storeName))) ?? transaction.create(Into<Store>())
					store.name = storeName
					item.store = store
				} else {
					item.store = nil
				}
				item.recordid = origItem.recordId
				item.comment = origItem.comment
				item.isWeight = origItem.isWeight
				item.price = Float(origItem.price)
				item.quantity = Float(origItem.quantity)
				item.purchased = origItem.isPurchased
				item.isRemoved = origItem.isRemoved
				item.isCrossListItem = origItem.isCrossListItem
				item.list = list
				return item
			})
			list.items = NSSet(array: items)
			return list
		}).eraseToAnyPublisher()
	}

	class func storeModels(models: [CloudKitShoppingList]) -> AnyPublisher<[ShoppingList], Error> {
		return Publishers.Sequence(sequence: models).flatMap({ storeModel(model: $0) }).collect().eraseToAnyPublisher()
	}
}
