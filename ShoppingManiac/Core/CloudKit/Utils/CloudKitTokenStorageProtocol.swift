//
//  CloudKitTokenStorageProtocol.swift
//  ShoppingManiac
//
//  Created by Dmitry Matyushkin on 1/24/20.
//  Copyright © 2020 Dmitry Matyushkin. All rights reserved.
//

import Foundation
import CloudKit

protocol CloudKitTokenStorageProtocol {
    func getZoneToken(zoneId: CKRecordZone.ID, localDb: Bool) -> CKServerChangeToken?
    func setZoneToken(zoneId: CKRecordZone.ID, localDb: Bool, token: CKServerChangeToken?)
    func getDbToken(localDb: Bool) -> CKServerChangeToken?
    func setDbToken(localDb: Bool, token: CKServerChangeToken?)
}
