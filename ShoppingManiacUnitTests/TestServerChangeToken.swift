//
//  TestServerChangeToken.swift
//  ShoppingManiacUnitTests
//
//  Created by Dmitry Matyushkin on 1/24/20.
//  Copyright © 2020 Dmitry Matyushkin. All rights reserved.
//

import Foundation
import CloudKit

class TokenTestArchiver: NSKeyedArchiver {
    
    override func decodeObject(forKey key: String) -> Any? {
        return nil
    }
}

class TestServerChangeToken: CKServerChangeToken {
    
    let key: String
    
    init?(key: String) {
        self.key = key
        let archiver = TokenTestArchiver()
        super.init(coder: archiver)
        archiver.finishEncoding()
    }
    
    required init?(coder: NSCoder) {
        self.key = "nothing"
        super.init(coder: coder)
    }
}
