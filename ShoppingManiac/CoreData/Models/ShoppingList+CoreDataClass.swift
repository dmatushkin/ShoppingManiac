//
//  ShoppingList+CoreDataClass.swift
//  ShoppingManiac
//
//  Created by Dmitry Matyushkin on 21/05/2017.
//  Copyright © 2017 Dmitry Matyushkin. All rights reserved.
//

import Foundation
import CoreData
import CoreStore
import SwiftyBeaver
import Combine

public class ShoppingList: NSManagedObject {

    var listItems: [ShoppingListItem] {
        return (Array(self.items ?? []) as? [ShoppingListItem]) ?? []
    }

	var itemsFetchBuilder: FetchChainBuilder<ShoppingListItem> {
		return From<ShoppingListItem>().where(Where("(list = %@ OR (isCrossListItem == true AND purchased == false)) AND isRemoved == false", self))
	}

    var isPurchased: Bool {
        guard let items = self.items else { return false }
        return items.count > 0 && (items.allObjects as? [ShoppingListItem] ?? []).filter({ $0.purchased == false }).isEmpty
    }

    fileprivate var dateString: String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = DateFormatter.Style.long
        dateFormatter.timeStyle = DateFormatter.Style.none
        return dateFormatter.string(from: Date(timeIntervalSinceReferenceDate: self.date))
    }

    var jsonDate: String {
        get {
            let dateFormatter = DateFormatter()
            dateFormatter.dateStyle = DateFormatter.Style.medium
            dateFormatter.timeStyle = DateFormatter.Style.medium
            return dateFormatter.string(from: Date(timeIntervalSinceReferenceDate: self.date))
        }
        set {
            let dateFormatter = DateFormatter()
            dateFormatter.dateStyle = DateFormatter.Style.medium
            dateFormatter.timeStyle = DateFormatter.Style.medium
            if let date = dateFormatter.date(from: newValue) {
                self.date = date.timeIntervalSinceReferenceDate
            } else {
                self.date = Date().timeIntervalSinceReferenceDate
            }
        }
    }

    var title: String {
        if let name = self.name, name.isEmpty == false {
            return name
        } else {
            return self.dateString
        }
    }

    func textData() -> String {
        var result = self.title + "\n"
        do {
            let itemsLine = try CoreStoreDefaults.dataStack.perform(synchronous: { transaction -> String in
                var result = ""
                let items = try transaction.fetchAll(From<ShoppingListItem>().where(Where("list = %@", self))).sorted( by: {item1, item2 in (item1.good?.name ?? "") < (item2.good?.name ?? "") })
				for item in items where !item.purchased {
                    var line = "\(item.good?.name ?? "") \(item.quantityText)"
                    if item.store != nil {
                        line += " : \(item.store?.name ?? "")"
                    }
                    result += (line + "\n")
                }
                return result
            })
            result += itemsLine
        } catch {
        }
        return result
    }

    func jsonData() -> Data? {
        var result = [String: Any]()

        result["name"] = self.name
        result["date"] = self.jsonDate

        do {
            let itemsArray = try CoreStoreDefaults.dataStack.perform(synchronous: { transaction -> [[String: Any]] in
                var resultItems = [[String: Any]]()
                let items = try transaction.fetchAll(From<ShoppingListItem>().where(Where("list = %@", self)))
                for item in items {
                    var itemDict = [String: Any]()
                    itemDict["good"] = item.good?.name ?? ""
                    itemDict["store"] = item.store?.name ?? ""
                    itemDict["price"] = item.price
                    itemDict["purchased"] = item.purchased
                    itemDict["purchaseDate"] = item.jsonPurchaseDate
                    itemDict["quantity"] = item.quantity
                    itemDict["isWeight"] = item.isWeight
                    itemDict["isCrossListItem"] = item.isCrossListItem
                    resultItems.append(itemDict)
                }
                return resultItems
            })
            result["items"] = itemsArray
        } catch {
        }

        return try? JSONSerialization.data(withJSONObject: result, options: [])
    }
    
    class func importShoppingList(fromJsonData jsonData: NSDictionary) -> ShoppingList? {
        do {
            let list: ShoppingList = try CoreStoreDefaults.dataStack.perform(synchronous: { transaction in
                let list = transaction.create(Into<ShoppingList>())
                list.name = jsonData["name"] as? String
                list.jsonDate = (jsonData["date"] as? String) ?? ""
				list.recordid = jsonData["recordId"] as? String
				list.isRemote = (jsonData["isRemote"] as? NSNumber)?.boolValue ?? false
                if let itemsArray = jsonData["items"] as? [NSDictionary] {
                    for itemDict in itemsArray {
                        let shoppingListItem = transaction.create(Into<ShoppingListItem>())
                        if let goodName = itemDict["good"] as? String, goodName.count > 0 {
                            if let good = try transaction.fetchOne(From<Good>().where(Where("name == %@", goodName))) {
                                shoppingListItem.good = good
                            } else {
                                let good = transaction.create(Into<Good>())
                                good.name = goodName
                                shoppingListItem.good = good
                            }
                        }
                        if let storeName = itemDict["store"] as? String, storeName.count > 0 {
                            if let store = try transaction.fetchOne(From<Store>().where(Where("name == %@", storeName))) {
                                shoppingListItem.store = store
                            } else {
                                let store = transaction.create(Into<Store>())
                                store.name = storeName
                                shoppingListItem.store = store
                            }
                        }
                        shoppingListItem.purchased = (itemDict["purchased"] as? NSNumber)?.boolValue ?? false
                        shoppingListItem.price = (itemDict["price"] as? NSNumber)?.floatValue ?? 0
                        shoppingListItem.quantity = (itemDict["quantity"] as? NSNumber)?.floatValue ?? 0
                        shoppingListItem.isWeight = (itemDict["isWeight"] as? NSNumber)?.boolValue ?? false
                        shoppingListItem.jsonPurchaseDate = (itemDict["purchaseDate"] as? String) ?? ""
                        shoppingListItem.isCrossListItem = (itemDict["isCrossListItem"] as? NSNumber)?.boolValue ?? false
						shoppingListItem.recordid = itemDict["recordId"] as? String
                        shoppingListItem.list = list
                    }
                }
                return list
            })
            return CoreStoreDefaults.dataStack.fetchExisting(list)
        } catch {
            return nil
        }
    }
}
