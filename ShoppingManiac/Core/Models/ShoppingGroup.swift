//
//  ShoppingGroup.swift
//  ShoppingManiac
//
//  Created by Dmitry Matyushkin on 29/05/2017.
//  Copyright © 2017 Dmitry Matyushkin. All rights reserved.
//

import Foundation
import CoreData

class ShoppingGroup {
    let groupName: String?
    let objectId: NSManagedObjectID?
    var items: [GroupItem]

    init(name: String?, objectId: NSManagedObjectID?, items: [GroupItem]) {
        self.groupName = name
        self.objectId = objectId
        self.items = items
    }
}
