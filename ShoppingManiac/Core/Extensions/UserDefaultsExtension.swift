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
            if let data = self.value(forKey: "LocalChangeToken") as? Data, let token = NSKeyedUnarchiver.unarchiveObject(with: data) as? CKServerChangeToken {
                return token
            } else {
                return nil
            }
        }
        set {
            if let token = newValue {
                let data = NSKeyedArchiver.archivedData(withRootObject: token)
                self.set(data, forKey: "LocalChangeToken")
                self.synchronize()
            } else {
                self.removeObject(forKey: "LocalChangeToken")
            }
        }
    }
    
    var sharedServerChangeToken: CKServerChangeToken? {
        get {
            if let data = self.value(forKey: "SharedChangeToken") as? Data, let token = NSKeyedUnarchiver.unarchiveObject(with: data) as? CKServerChangeToken {
                return token
            } else {
                return nil
            }
        }
        set {
            if let token = newValue {
                let data = NSKeyedArchiver.archivedData(withRootObject: token)
                self.set(data, forKey: "SharedChangeToken")
                self.synchronize()
            } else {
                self.removeObject(forKey: "SharedChangeToken")
            }
        }
    }
}
