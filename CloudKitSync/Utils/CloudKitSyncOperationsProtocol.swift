//
//  CloudKitSyncOperationsProtocol.swift
//  CloudKitSync
//
//  Created by Dmitry Matyushkin on 8/14/20.
//  Copyright © 2020 Dmitry Matyushkin. All rights reserved.
//

import Foundation
import CloudKit

public protocol CloudKitSyncOperationsProtocol {
    func run(operation: CKDatabaseOperation, localDb: Bool)
}
