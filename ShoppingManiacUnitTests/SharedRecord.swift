//
//  SharedRecord.swift
//  ShoppingManiacUnitTests
//
//  Created by Dmitry Matyushkin on 1/31/20.
//  Copyright © 2020 Dmitry Matyushkin. All rights reserved.
//

import CloudKit

class SharedRecord: CKRecord {
    
    override var share: CKRecord.Reference? {
        let recordId = CKRecord.ID(recordName: "shareTestRecord")
        let record = CKRecord(recordType: "cloudkit.share", recordID: recordId)
        return CKRecord.Reference(record: record, action: .none)
    }
}
