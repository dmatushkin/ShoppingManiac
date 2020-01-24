//
//  ZonesToFetchWrapper.swift
//  ShoppingManiac
//
//  Created by Dmitry Matyushkin on 9/16/19.
//  Copyright © 2019 Dmitry Matyushkin. All rights reserved.
//

import Foundation
import CloudKit

class ZonesToFetchWrapper {
    
    let localDb: Bool
    let zoneIds: [CKRecordZone.ID]
    
    init(localDb: Bool, zoneIds: [CKRecordZone.ID]) {
        self.localDb = localDb
        self.zoneIds = zoneIds
    }
}
