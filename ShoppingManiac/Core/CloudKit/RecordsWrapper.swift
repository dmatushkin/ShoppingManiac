//
//  RecordsWrapper.swift
//  ShoppingManiac
//
//  Created by Dmitry Matyushkin on 22/04/2018.
//  Copyright © 2018 Dmitry Matyushkin. All rights reserved.
//

import Foundation
import CloudKit

class RecordsWrapper {
    
    let database: CKDatabase
    let records:[CKRecord]
    
    init(database: CKDatabase, records: [CKRecord]) {
        self.database = database
        self.records = records
    }
}
