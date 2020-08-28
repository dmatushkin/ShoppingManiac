//
//  CloudKitSyncSharePermissionsTests.swift
//  CloudKitSyncTests
//
//  Created by Dmitry Matyushkin on 8/28/20.
//  Copyright © 2020 Dmitry Matyushkin. All rights reserved.
//

import XCTest
import CoreStore
import CloudKit
import Combine
import DependencyInjection
import CommonError
@testable import CloudKitSync

class CloudKitSyncSharePermissionsTests: XCTestCase {

	private let operations = CloudKitSyncTestOperations()
	private let utilsStub = CloudKitSyncUtilsStub()
	private var cloudShare: CloudKitSyncShare!

	override func setUp() {
        self.operations.cleanup()
		DIProvider.shared
			.register(forType: CloudKitSyncOperationsProtocol.self, object: self.operations)
			.register(forType: CloudKitSyncUtilsProtocol.self, lambda: { self.utilsStub })
        self.cloudShare = CloudKitSyncShare()
    }

	override func tearDown() {
		DIProvider.shared.clear()
        self.cloudShare = nil
		self.utilsStub.cleanup()
    }

	func testShareSetupPermissionsGrantedSuccess() {
		var operationsCount: Int = 0
		self.operations.onAccountStatus = {
			operationsCount += 1
			return (CKAccountStatus.available, nil)
		}
		self.operations.onPermissionStatus = {permission in
			operationsCount += 1
			XCTAssertEqual(permission, .userDiscoverability)
			return (CKContainer_Application_PermissionStatus.granted, nil)
		}
		self.operations.onSaveZone = { zone in
			operationsCount += 1
			XCTAssertEqual(zone.zoneID.zoneName, TestShoppingList.zoneName)
			return (zone, nil)
		}
		do {
			_ = try cloudShare.setupUserPermissions(itemType: TestShoppingList.self).getValue(test: self, timeout: 10)
		} catch {
			XCTAssert(false, "Should not be any errors here")
		}
		XCTAssertEqual(operationsCount, 3)
	}

	func testShareSetupPermissionsInitialStateSuccess() {
		var operationsCount: Int = 0
		self.operations.onAccountStatus = {
			operationsCount += 1
			return (CKAccountStatus.available, nil)
		}
		self.operations.onPermissionStatus = {permission in
			operationsCount += 1
			XCTAssertEqual(permission, .userDiscoverability)
			return (CKContainer_Application_PermissionStatus.initialState, nil)
		}
		self.operations.onRequestAppPermission = { permission in
			operationsCount += 1
			XCTAssertEqual(permission, .userDiscoverability)
			return (CKContainer_Application_PermissionStatus.granted, nil)
		}
		self.operations.onSaveZone = { zone in
			operationsCount += 1
			XCTAssertEqual(zone.zoneID.zoneName, TestShoppingList.zoneName)
			return (zone, nil)
		}
		do {
			_ = try cloudShare.setupUserPermissions(itemType: TestShoppingList.self).getValue(test: self, timeout: 10)
		} catch {
			XCTAssert(false, "Should not be any errors here")
		}
		XCTAssertEqual(operationsCount, 4)
	}

	func testShareSetupPermissionsAccountStatusCouldNotDetermine() {
		var operationsCount: Int = 0
		self.operations.onAccountStatus = {
			operationsCount += 1
			return (CKAccountStatus.couldNotDetermine, nil)
		}
		do {
			_ = try cloudShare.setupUserPermissions(itemType: TestShoppingList.self).getValue(test: self, timeout: 10)
			XCTAssert(false, "Error should happened")
		} catch {
			XCTAssertEqual(error.localizedDescription, "CloudKit account status incorrect")
		}
		XCTAssertEqual(operationsCount, 1)
	}

	func testShareSetupPermissionsAccountStatusRestricted() {
		var operationsCount: Int = 0
		self.operations.onAccountStatus = {
			operationsCount += 1
			return (CKAccountStatus.restricted, nil)
		}
		do {
			_ = try cloudShare.setupUserPermissions(itemType: TestShoppingList.self).getValue(test: self, timeout: 10)
			XCTAssert(false, "Error should happened")
		} catch {
			XCTAssertEqual(error.localizedDescription, "CloudKit account is restricted")
		}
		XCTAssertEqual(operationsCount, 1)
	}

	func testShareSetupPermissionsAccountStatusNoAccount() {
		var operationsCount: Int = 0
		self.operations.onAccountStatus = {
			operationsCount += 1
			return (CKAccountStatus.noAccount, nil)
		}
		do {
			_ = try cloudShare.setupUserPermissions(itemType: TestShoppingList.self).getValue(test: self, timeout: 10)
			XCTAssert(false, "Error should happened")
		} catch {
			XCTAssertEqual(error.localizedDescription, "CloudKit account does not exist")
		}
		XCTAssertEqual(operationsCount, 1)
	}

	func testShareSetupPermissionsAccountStatusCustomError() {
		var operationsCount: Int = 0
		self.operations.onAccountStatus = {
			operationsCount += 1
			return (CKAccountStatus.noAccount, CommonError(description: "test error") as Error)
		}
		do {
			_ = try cloudShare.setupUserPermissions(itemType: TestShoppingList.self).getValue(test: self, timeout: 10)
			XCTAssert(false, "Error should happened")
		} catch {
			XCTAssertEqual(error.localizedDescription, "test error")
		}
		XCTAssertEqual(operationsCount, 1)
	}

	func testShareSetupPermissionsPermissionStatusCouldNotComplete() {
		var operationsCount: Int = 0
		self.operations.onAccountStatus = {
			operationsCount += 1
			return (CKAccountStatus.available, nil)
		}
		self.operations.onPermissionStatus = {permission in
			operationsCount += 1
			XCTAssertEqual(permission, .userDiscoverability)
			return (CKContainer_Application_PermissionStatus.couldNotComplete, nil)
		}
		do {
			_ = try cloudShare.setupUserPermissions(itemType: TestShoppingList.self).getValue(test: self, timeout: 10)
			XCTAssert(false, "Error should happened")
		} catch {
			XCTAssertEqual(error.localizedDescription, "CloudKit permission status could not complete")
		}
		XCTAssertEqual(operationsCount, 2)
	}

	func testShareSetupPermissionsPermissionStatusDenied() {
		var operationsCount: Int = 0
		self.operations.onAccountStatus = {
			operationsCount += 1
			return (CKAccountStatus.available, nil)
		}
		self.operations.onPermissionStatus = {permission in
			operationsCount += 1
			XCTAssertEqual(permission, .userDiscoverability)
			return (CKContainer_Application_PermissionStatus.denied, nil)
		}
		do {
			_ = try cloudShare.setupUserPermissions(itemType: TestShoppingList.self).getValue(test: self, timeout: 10)
			XCTAssert(false, "Error should happened")
		} catch {
			XCTAssertEqual(error.localizedDescription, "CloudKit permission status denied")
		}
		XCTAssertEqual(operationsCount, 2)
	}

	func testShareSetupPermissionsPermissionStatusCustomError() {
		var operationsCount: Int = 0
		self.operations.onAccountStatus = {
			operationsCount += 1
			return (CKAccountStatus.available, nil)
		}
		self.operations.onPermissionStatus = {permission in
			operationsCount += 1
			XCTAssertEqual(permission, .userDiscoverability)
			return (CKContainer_Application_PermissionStatus.denied, CommonError(description: "test error") as Error)
		}
		do {
			_ = try cloudShare.setupUserPermissions(itemType: TestShoppingList.self).getValue(test: self, timeout: 10)
			XCTAssert(false, "Error should happened")
		} catch {
			XCTAssertEqual(error.localizedDescription, "test error")
		}
		XCTAssertEqual(operationsCount, 2)
	}

	func testShareSetupPermissionsRequestPermissionStatusCouldNotComplete() {
		var operationsCount: Int = 0
		self.operations.onAccountStatus = {
			operationsCount += 1
			return (CKAccountStatus.available, nil)
		}
		self.operations.onPermissionStatus = {permission in
			operationsCount += 1
			XCTAssertEqual(permission, .userDiscoverability)
			return (CKContainer_Application_PermissionStatus.initialState, nil)
		}
		self.operations.onRequestAppPermission = { permission in
			operationsCount += 1
			XCTAssertEqual(permission, .userDiscoverability)
			return (CKContainer_Application_PermissionStatus.couldNotComplete, nil)
		}
		do {
			_ = try cloudShare.setupUserPermissions(itemType: TestShoppingList.self).getValue(test: self, timeout: 10)
			XCTAssert(false, "Error should happened")
		} catch {
			XCTAssertEqual(error.localizedDescription, "CloudKit permission status could not complete")
		}
		XCTAssertEqual(operationsCount, 3)
	}

	func testShareSetupPermissionsRequestPermissionStatusDenied() {
		var operationsCount: Int = 0
		self.operations.onAccountStatus = {
			operationsCount += 1
			return (CKAccountStatus.available, nil)
		}
		self.operations.onPermissionStatus = {permission in
			operationsCount += 1
			XCTAssertEqual(permission, .userDiscoverability)
			return (CKContainer_Application_PermissionStatus.initialState, nil)
		}
		self.operations.onRequestAppPermission = { permission in
			operationsCount += 1
			XCTAssertEqual(permission, .userDiscoverability)
			return (CKContainer_Application_PermissionStatus.denied, nil)
		}
		do {
			_ = try cloudShare.setupUserPermissions(itemType: TestShoppingList.self).getValue(test: self, timeout: 10)
			XCTAssert(false, "Error should happened")
		} catch {
			XCTAssertEqual(error.localizedDescription, "CloudKit permission status denied")
		}
		XCTAssertEqual(operationsCount, 3)
	}

	func testShareSetupPermissionsRequestPermissionStatusCustomError() {
		var operationsCount: Int = 0
		self.operations.onAccountStatus = {
			operationsCount += 1
			return (CKAccountStatus.available, nil)
		}
		self.operations.onPermissionStatus = {permission in
			operationsCount += 1
			XCTAssertEqual(permission, .userDiscoverability)
			return (CKContainer_Application_PermissionStatus.initialState, nil)
		}
		self.operations.onRequestAppPermission = { permission in
			operationsCount += 1
			XCTAssertEqual(permission, .userDiscoverability)
			return (CKContainer_Application_PermissionStatus.denied, CommonError(description: "test error") as Error)
		}
		do {
			_ = try cloudShare.setupUserPermissions(itemType: TestShoppingList.self).getValue(test: self, timeout: 10)
			XCTAssert(false, "Error should happened")
		} catch {
			XCTAssertEqual(error.localizedDescription, "test error")
		}
		XCTAssertEqual(operationsCount, 3)
	}

	func testShareSetupPermissionsSaveZoneCustomError() {
		var operationsCount: Int = 0
		self.operations.onAccountStatus = {
			operationsCount += 1
			return (CKAccountStatus.available, nil)
		}
		self.operations.onPermissionStatus = {permission in
			operationsCount += 1
			XCTAssertEqual(permission, .userDiscoverability)
			return (CKContainer_Application_PermissionStatus.initialState, nil)
		}
		self.operations.onRequestAppPermission = { permission in
			operationsCount += 1
			XCTAssertEqual(permission, .userDiscoverability)
			return (CKContainer_Application_PermissionStatus.granted, nil)
		}
		self.operations.onSaveZone = { zone in
			operationsCount += 1
			XCTAssertEqual(zone.zoneID.zoneName, TestShoppingList.zoneName)
			return (zone, CommonError(description: "test error") as Error)
		}
		do {
			_ = try cloudShare.setupUserPermissions(itemType: TestShoppingList.self).getValue(test: self, timeout: 10)
			XCTAssert(false, "Error should happened")
		} catch {
			XCTAssertEqual(error.localizedDescription, "test error")
		}
		XCTAssertEqual(operationsCount, 4)
	}
}
