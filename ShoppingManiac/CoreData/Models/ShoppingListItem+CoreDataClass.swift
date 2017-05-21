//
//  ShoppingListItem+CoreDataClass.swift
//  ShoppingManiac
//
//  Created by Dmitry Matyushkin on 21/05/2017.
//  Copyright © 2017 Dmitry Matyushkin. All rights reserved.
//

import Foundation
import CoreData


public class ShoppingListItem: NSManagedObject {

    var quantityText : String {
        get {
            return self.isWeight ? "\(self.quantity)" : "\(Int(self.quantity))"
        }
    }
    
    var jsonPurchaseDate : String {
        get {
            let dateFormatter = DateFormatter()
            dateFormatter.dateStyle = DateFormatter.Style.medium
            dateFormatter.timeStyle = DateFormatter.Style.medium
            return dateFormatter.string(from: Date(timeIntervalSince1970: self.purchaseDate))
        }
        set {
            let dateFormatter = DateFormatter()
            dateFormatter.dateStyle = DateFormatter.Style.medium
            dateFormatter.timeStyle = DateFormatter.Style.medium
            if let date = dateFormatter.date(from: newValue) {
                self.purchaseDate = date.timeIntervalSince1970
            } else {
                self.purchaseDate = Date().timeIntervalSince1970
            }
        }
    }
    
    var totalPrice : Double {
        return Double(price * quantity)
    }
    
    func isInStore(_ inStore : Store?) -> Bool {
        return self.price != 0 && self.store != nil && (inStore == nil || inStore?.name == self.store?.name)
    }
}
