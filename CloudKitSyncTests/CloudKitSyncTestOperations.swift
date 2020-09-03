//
//  CloudKitSyncTestOperations.swift
//  CloudKitSyncTests
//
//  Created by Dmitry Matyushkin on 8/14/20.
//  Copyright © 2020 Dmitry Matyushkin. All rights reserved.
//

import Foundation
import CloudKit
import CloudKitSync

class CloudKitSyncTestOperations: CloudKitSyncOperationsProtocol {

    private let operationsQueue = DispatchQueue(label: "CloudKitTestOperations.operationsQueue", attributes: .concurrent)

    var localOperations: [CKDatabaseOperation] = []
    var sharedOperations: [CKDatabaseOperation] = []
	var containerOperations: [CKOperation] = []
    var onAddOperation: ((CKDatabaseOperation, [CKDatabaseOperation], [CKDatabaseOperation]) -> Void)?
	var onContainerOperation: ((CKOperation, [CKOperation]) -> Void)?
	var onAccountStatus: (() -> (CKAccountStatus, Error?))?
	var onPermissionStatus: ((CKContainer_Application_Permissions) -> (CKContainer_Application_PermissionStatus, Error?))?
	var onRequestAppPermission: ((CKContainer_Application_Permissions) -> (CKContainer_Application_PermissionStatus, Error?))?
	var onSaveZone: ((CKRecordZone) -> (CKRecordZone?, Error?))?

    func cleanup() {
        self.localOperations = []
        self.sharedOperations = []
		self.containerOperations = []
        self.onAddOperation = nil
		self.onContainerOperation = nil
		self.onAccountStatus = nil
		self.onPermissionStatus = nil
		self.onRequestAppPermission = nil
		self.onSaveZone = nil
    }

    func run(operation: CKDatabaseOperation, localDb: Bool) {
        if localDb {
            localOperations.append(operation)
        } else {
            sharedOperations.append(operation)
        }
        self.operationsQueue.async {[weak self] in
            guard let self = self else { return }
            self.onAddOperation?(operation, self.localOperations, self.sharedOperations)
        }
    }

	func accountStatus(completionHandler: @escaping (CKAccountStatus, Error?) -> Void) {
		self.operationsQueue.async {[weak self] in
			guard let self = self, let onAccountStatus = self.onAccountStatus else { return }
			let (status, error) = onAccountStatus()
			completionHandler(status, error)
		}
	}

	func permissionStatus(forApplicationPermission applicationPermission: CKContainer_Application_Permissions, completionHandler: @escaping CKContainer_Application_PermissionBlock) {
		self.operationsQueue.async {[weak self] in
			guard let self = self, let onPermissionStatus = self.onPermissionStatus else { return }
			let (status, error) = onPermissionStatus(applicationPermission)
			completionHandler(status, error)
		}
	}

	func requestApplicationPermission(_ applicationPermission: CKContainer_Application_Permissions, completionHandler: @escaping CKContainer_Application_PermissionBlock) {
		self.operationsQueue.async {[weak self] in
			guard let self = self, let onPermissionStatus = self.onRequestAppPermission else { return }
			let (status, error) = onPermissionStatus(applicationPermission)
			completionHandler(status, error)
		}
	}

	func saveZone(_ zone: CKRecordZone, completionHandler: @escaping (CKRecordZone?, Error?) -> Void) {
		self.operationsQueue.async {[weak self] in
			guard let self = self, let onSaveZone = self.onSaveZone else { return }
			let (zone, error) = onSaveZone(zone)
			completionHandler(zone, error)
		}
	}

	func run(operation: CKOperation) {
		self.containerOperations.append(operation)
		self.operationsQueue.async {[weak self] in
			guard let self = self, let onContainerOperation = self.onContainerOperation else { return }
			onContainerOperation(operation, self.containerOperations)
		}
	}
}
