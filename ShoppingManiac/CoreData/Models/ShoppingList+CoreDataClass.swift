//
//  ShoppingList+CoreDataClass.swift
//  ShoppingManiac
//
//  Created by Dmitry Matyushkin on 21/05/2017.
//  Copyright © 2017 Dmitry Matyushkin. All rights reserved.
//

import Foundation
import CoreData
import SwiftyBeaver

public class ShoppingList: NSManagedObject {

    var listItems: [ShoppingListItem] {
        return (Array(self.items ?? []) as? [ShoppingListItem]) ?? []
    }

    func setRecordId(recordId: String) {
        DAO.performSync(updates: {[weak self] context -> Void in
            guard let self = self else { return }
            if let shoppingList: ShoppingList = context.edit(self) {
                shoppingList.recordid = recordId
            }
        })
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
        let itemsLine = DAO.performSync(updates: {[weak self] context -> String in
            guard let self = self else { return "" }
            var result = ""
            let items = context.fetchAll(ShoppingListItem.self, predicate: NSPredicate(format: "list = %@", self)).sorted( by: {item1, item2 in (item1.good?.name ?? "") < (item2.good?.name ?? "") })
            for item in items {
                var line = "\(item.good?.name ?? "") \(item.quantityText)"
                if item.store != nil {
                    line += " : \(item.store?.name ?? "")"
                }
                result += (line + "\n")
            }
            return result
        }) ?? ""
        result += itemsLine
        return result
    }

    func jsonData() -> Data? {
        var result = [String: Any]()

        result["name"] = self.name
        result["date"] = self.jsonDate
        let itemsArray = DAO.performSync(updates: {[weak self] context -> [[String: Any]] in
            guard let self = self else { return [] }
            var resultItems = [[String: Any]]()
            let items = context.fetchAll(ShoppingListItem.self, predicate: NSPredicate(format: "list = %@", self))
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
        }) ?? []
        result["items"] = itemsArray
        return try? JSONSerialization.data(withJSONObject: result, options: [])
    }
    
    class func importShoppingList(fromJsonData jsonData: NSDictionary) -> ShoppingList? {
        let list = DAO.performSync(updates: {context -> ShoppingList in
            let list: ShoppingList = context.create()
            list.name = jsonData["name"] as? String
            list.jsonDate = (jsonData["date"] as? String) ?? ""
            if let itemsArray = jsonData["items"] as? [NSDictionary] {
                for itemDict in itemsArray {
                    let shoppingListItem: ShoppingListItem = context.create()
                    if let goodName = itemDict["good"] as? String, goodName.count > 0 {
                        if let good = context.fetchOne(Good.self, predicate: NSPredicate(format: "name == %@", goodName)) {
                            shoppingListItem.good = good
                        } else {
                            let good: Good = context.create()
                            good.name = goodName
                            shoppingListItem.good = good
                        }
                    }
                    if let storeName = itemDict["store"] as? String, storeName.count > 0 {
                        if let store = context.fetchOne(Store.self, predicate: NSPredicate(format: "name == %@", storeName)) {
                            shoppingListItem.store = store
                        } else {
                            let store: Store = context.create()
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
                    shoppingListItem.list = list
                }
            }
            return list
        })
        return DAO.fetchExisting(list)
    }
}
