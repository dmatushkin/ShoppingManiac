//
//  UserDefaultsExtension.swift
//  ShoppingManiac
//
//  Created by Dmitry Matyushkin on 29/04/2018.
//  Copyright © 2018 Dmitry Matyushkin. All rights reserved.
//

import Foundation
import CloudKit

extension UserDefaults {
    
    var localServerChangeToken: CKServerChangeToken? {
        get {
            
            if let data = self.value(forKey: "LocalChangeToken") as? Data, let token = try? NSKeyedUnarchiver.unarchivedObject(ofClasses: [CKServerChangeToken.self], from: data) as? CKServerChangeToken {
                return token
            } else {
                return nil
            }
        }
        set {
            if let token = newValue, let data = try? NSKeyedArchiver.archivedData(withRootObject: token, requiringSecureCoding: false) {
                self.set(data, forKey: "LocalChangeToken")
                self.synchronize()
            } else {
                self.removeObject(forKey: "LocalChangeToken")
            }
        }
    }
    
    var sharedServerChangeToken: CKServerChangeToken? {
        get {
            if let data = self.value(forKey: "SharedChangeToken") as? Data, let token = try? NSKeyedUnarchiver.unarchivedObject(ofClasses: [CKServerChangeToken.self], from: data) as? CKServerChangeToken {
                return token
            } else {
                return nil
            }
        }
        set {
            if let token = newValue, let data = try? NSKeyedArchiver.archivedData(withRootObject: token, requiringSecureCoding: false) {
                self.set(data, forKey: "SharedChangeToken")
                self.synchronize()
            } else {
                self.removeObject(forKey: "SharedChangeToken")
            }
        }
    }
    
    func setZoneChangeToken(zoneName: String, token: CKServerChangeToken?) {
        let key = "zoneChangeToken\(zoneName)"
        if let token = token, let data = try? NSKeyedArchiver.archivedData(withRootObject: token, requiringSecureCoding: false) {
            self.set(data, forKey: key)
            self.synchronize()
        } else {
            self.removeObject(forKey: key)
        }
    }
    
    func getZoneChangedToken(zoneName: String) -> CKServerChangeToken? {
        let key = "zoneChangeToken\(zoneName)"
        if let data = self.value(forKey: key) as? Data, let token = try? NSKeyedUnarchiver.unarchivedObject(ofClasses: [CKServerChangeToken.self], from: data) as? CKServerChangeToken {
            return token
        } else {
            return nil
        }
    }
}
