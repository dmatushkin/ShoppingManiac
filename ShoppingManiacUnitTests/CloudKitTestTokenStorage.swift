//
//  CloudKitTestTokenStorage.swift
//  ShoppingManiacUnitTests
//
//  Created by Dmitry Matyushkin on 1/24/20.
//  Copyright © 2020 Dmitry Matyushkin. All rights reserved.
//

import Foundation
import CloudKit
import CloudKitSync

class CloudKitTestTokenStorage: CloudKitSyncTokenStorageProtocol {
    
    var zoneStorage: [String: CKServerChangeToken] = [:]
    var localToken: CKServerChangeToken?
    var sharedToken: CKServerChangeToken?
    
    func cleanup() {
        zoneStorage = [:]
        localToken = nil
        sharedToken = nil
    }
    
    private func zoneTokenDefaultsKey(zoneId: CKRecordZone.ID, localDb: Bool) -> String {
        return zoneId.zoneName + (localDb ? "local" : "remote")
    }
    
    func getZoneToken(zoneId: CKRecordZone.ID, localDb: Bool) -> CKServerChangeToken? {
        return self.zoneStorage[self.zoneTokenDefaultsKey(zoneId: zoneId, localDb: localDb)]
    }
    
    func setZoneToken(zoneId: CKRecordZone.ID, localDb: Bool, token: CKServerChangeToken?) {
        self.zoneStorage[self.zoneTokenDefaultsKey(zoneId: zoneId, localDb: localDb)] = token
    }
    
    func getDbToken(localDb: Bool) -> CKServerChangeToken? {
        if localDb {
            return self.localToken
        } else {
            return self.sharedToken
        }
    }
    
    func setDbToken(localDb: Bool, token: CKServerChangeToken?) {
        if localDb {
            self.localToken = token
        } else {
            self.sharedToken = token
        }
    }
}
