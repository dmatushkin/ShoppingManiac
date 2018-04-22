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
    let database: CKDatabase

    init(record: CKRecord, database: CKDatabase) {
        self.record = record
        self.database = database
    }
}
