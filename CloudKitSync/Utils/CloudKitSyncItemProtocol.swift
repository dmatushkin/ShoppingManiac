//
//  CloudKitSyncItemProtocol.swift
//  CloudKitSync
//
//  Created by Dmitry Matyushkin on 8/14/20.
//  Copyright © 2020 Dmitry Matyushkin. All rights reserved.
//

import Foundation
import CloudKit
import Combine

public protocol CloudKitSyncItemProtocol {
	static var zoneName: String { get }
	static var recordType: String { get }
	var isRemote: Bool { get }
	func dependentItems() -> [CloudKitSyncItemProtocol]
	var recordId: String? { get }
	func setRecordId(_ recordId: String) -> AnyPublisher<Void, Error>
	func populate(record: CKRecord, dependentRecords: [CKRecord])
	static func store(records: [CKRecord]) -> AnyPublisher<Void, Error>
}
