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

	func run(operation: CKOperation) {
		CKContainer.default().add(operation)
	}

	func accountStatus(completionHandler: @escaping (CKAccountStatus, Error?) -> Void) {
		CKContainer.default().accountStatus(completionHandler: completionHandler)
	}

	func permissionStatus(forApplicationPermission applicationPermission: CKContainer_Application_Permissions, completionHandler: @escaping CKContainer_Application_PermissionBlock) {
		CKContainer.default().status(forApplicationPermission: applicationPermission, completionHandler: completionHandler)
	}

	func saveZone(_ zone: CKRecordZone, completionHandler: @escaping (CKRecordZone?, Error?) -> Void) {
		CKContainer.default().privateCloudDatabase.save(zone, completionHandler: completionHandler)
	}

	func requestApplicationPermission(_ applicationPermission: CKContainer_Application_Permissions, completionHandler: @escaping CKContainer_Application_PermissionBlock) {
		CKContainer.default().requestApplicationPermission(applicationPermission, completionHandler: completionHandler)
	}
}
