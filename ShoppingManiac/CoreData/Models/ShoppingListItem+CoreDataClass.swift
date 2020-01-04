//
//  ShoppingListItem+CoreDataClass.swift
//  ShoppingManiac
//
//  Created by Dmitry Matyushkin on 21/05/2017.
//  Copyright © 2017 Dmitry Matyushkin. All rights reserved.
//

import Foundation
import CoreData
import CoreStore
import SwiftyBeaver

public class ShoppingListItem: NSManagedObject {

    func setRecordId(recordId: String) {
        _ = try? CoreStoreDefaults.dataStack.perform(synchronous: {[weak self] transaction -> Void in
            guard let self = self else { return }
            if let shoppingListItem: ShoppingListItem = transaction.edit(self) {
                shoppingListItem.recordid = recordId
            }
        })
    }
    
    var quantityText: String {
        return self.isWeight ? "\(self.quantity)" : "\(Int(self.quantity))"
    }

    var jsonPurchaseDate: String {
        get {
            let dateFormatter = DateFormatter()
            dateFormatter.dateStyle = DateFormatter.Style.medium
            dateFormatter.timeStyle = DateFormatter.Style.medium
            return dateFormatter.string(from: Date(timeIntervalSinceReferenceDate: self.purchaseDate))
        }
        set {
            let dateFormatter = DateFormatter()
            dateFormatter.dateStyle = DateFormatter.Style.medium
            dateFormatter.timeStyle = DateFormatter.Style.medium
            if let date = dateFormatter.date(from: newValue) {
                self.purchaseDate = date.timeIntervalSinceReferenceDate
            } else {
                self.purchaseDate = Date().timeIntervalSinceReferenceDate
            }
        }
    }

    var totalPrice: Double {
        return Double(price * quantity)
    }

    func isInStore(_ inStore: Store?) -> Bool {
        return self.price != 0 && self.store != nil && (inStore == nil || inStore?.name == self.store?.name)
    }
}
