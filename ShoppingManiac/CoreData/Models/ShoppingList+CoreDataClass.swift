//
//  ShoppingList+CoreDataClass.swift
//  ShoppingManiac
//
//  Created by Dmitry Matyushkin on 21/05/2017.
//  Copyright © 2017 Dmitry Matyushkin. All rights reserved.
//

import Foundation
import CoreData


public class ShoppingList: NSManagedObject {

    var isPurchased : Bool {
        guard let items = self.items else { return false }
        return items.count > 0 && (items.allObjects as! [ShoppingListItem]).filter( { $0.purchased == false } ).isEmpty
    }
    
    fileprivate var dateString : String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = DateFormatter.Style.long
        dateFormatter.timeStyle = DateFormatter.Style.none
        return dateFormatter.string(from: Date(timeIntervalSinceReferenceDate: self.date))
    }
    
    var jsonDate : String {
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
    
    var title : String {
        get {
            if let name = self.name, name.isEmpty == false {
                return name
            } else {
                return self.dateString
            }
        }
    }
    
    func textData() -> String {
        var result = self.title + "\n"
        if let unsortedItems = self.items?.allObjects as? [ShoppingListItem] {
            let sortedItems = unsortedItems.sorted( by: { ($0.good?.name ?? "") < ($1.good?.name ?? "") } )
            for item in sortedItems {
                var line = "\(item.good?.name ?? "") \(item.quantityText)"
                if item.store != nil {
                    line += " : \(item.store?.name ?? "")"
                }
                result += (line + "\n")
            }
        }
        return result
    }
    
    func jsonData() -> Data? {
        let result = NSMutableDictionary()
        
        result["name"] = self.name
        result["date"] = self.jsonDate
        
        let itemsArray = NSMutableArray()
        if let items = self.items?.allObjects as? [ShoppingListItem] {
            for item in items {
                let itemDict = NSMutableDictionary()
                
                itemDict["good"] = item.good?.name ?? ""
                itemDict["store"] = item.store?.name ?? ""
                itemDict["price"] = item.price
                itemDict["purchased"] = item.purchased
                itemDict["purchaseDate"] = item.jsonPurchaseDate
                itemDict["quantity"] = item.quantity
                itemDict["isWeight"] = item.isWeight
                
                itemsArray.add(itemDict)
            }
        }
        result["items"] = itemsArray
        
        return try? JSONSerialization.data(withJSONObject: result, options: [])
    }
}
