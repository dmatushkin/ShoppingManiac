//
//  CloudKitOperations.swift
//  ShoppingManiac
//
//  Created by Dmitry Matyushkin on 1/23/20.
//  Copyright © 2020 Dmitry Matyushkin. All rights reserved.
//

import Foundation
import CloudKit
import DependencyInjection
import CloudKitSync

class CloudKitOperations: CloudKitSyncOperationsProtocol, DIDependency {

	required init() {}

	func run(operation: CKDatabaseOperation, localDb: Bool) {
		CKContainer.default().database(localDb: localDb).add(operation)
	}
}
