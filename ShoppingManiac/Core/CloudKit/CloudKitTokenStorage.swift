//
//  CloudKitTokenStorage.swift
//  ShoppingManiac
//
//  Created by Dmitry Matyushkin on 1/23/20.
//  Copyright © 2020 Dmitry Matyushkin. All rights reserved.
//

import Foundation
import CloudKit

class CloudKitTokenStorage {

	private init() {}
	
	private class func zoneTokenDefaultsKey(zoneId: CKRecordZone.ID, localDb: Bool) -> String {
		return zoneId.zoneName + (localDb ? "local" : "remote")
	}
	
	class func getZoneToken(zoneId: CKRecordZone.ID, localDb: Bool) -> CKServerChangeToken? {
		return UserDefaults.standard.getZoneChangedToken(zoneName: zoneTokenDefaultsKey(zoneId: zoneId, localDb: localDb))
	}
	
	class func setZoneToken(zoneId: CKRecordZone.ID, localDb: Bool, token: CKServerChangeToken?) {
		UserDefaults.standard.setZoneChangeToken(zoneName: zoneTokenDefaultsKey(zoneId: zoneId, localDb: localDb), token: token)
	}
	
	class func getDbToken(localDb: Bool) -> CKServerChangeToken? {
		if localDb {
            return UserDefaults.standard.localServerChangeToken
        } else {
            return UserDefaults.standard.sharedServerChangeToken
        }
	}
	
	class func setDbToken(localDb: Bool, token: CKServerChangeToken?) {
		if localDb {
            UserDefaults.standard.localServerChangeToken = token
        } else {
            UserDefaults.standard.sharedServerChangeToken = token
        }
	}
}
