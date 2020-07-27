//
//  ShoppingGroup.swift
//  ShoppingManiac
//
//  Created by Dmitry Matyushkin on 29/05/2017.
//  Copyright © 2017 Dmitry Matyushkin. All rights reserved.
//

import Foundation
import CoreData

struct ShoppingGroup: Hashable {
    let groupName: String?
    let objectId: NSManagedObjectID?

    init(name: String?, objectId: NSManagedObjectID?) {
        self.groupName = name
        self.objectId = objectId
    }
}
