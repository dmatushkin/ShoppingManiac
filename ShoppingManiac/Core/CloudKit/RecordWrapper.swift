//
//  RecordWrapper.swift
//  ShoppingManiac
//
//  Created by Dmitry Matyushkin on 22/04/2018.
//  Copyright © 2018 Dmitry Matyushkin. All rights reserved.
//

import Foundation
import CloudKit

class RecordWrapper {
    let record: CKRecord
    let localDb: Bool
    let ownerName: String?

    init(record: CKRecord, localDb: Bool, ownerName: String?) {
        self.record = record
        self.localDb = localDb
        self.ownerName = ownerName
    }
}
