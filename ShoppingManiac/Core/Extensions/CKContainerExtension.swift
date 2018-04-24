//
//  CKContainerExtension.swift
//  ShoppingManiac
//
//  Created by Dmitry Matyushkin on 24/04/2018.
//  Copyright © 2018 Dmitry Matyushkin. All rights reserved.
//

import Foundation
import CloudKit

extension CKContainer {
    
    func database(localDb: Bool) -> CKDatabase {
        return localDb ? privateCloudDatabase : sharedCloudDatabase
    }
}
