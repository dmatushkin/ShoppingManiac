//
//  CloudSubscriptions.swift
//  ShoppingManiac
//
//  Created by Dmitry Matyushkin on 28/04/2018.
//  Copyright © 2018 Dmitry Matyushkin. All rights reserved.
//

import Foundation
import CloudKit
import Hydra

class CloudSubscriptions {
    
    private static let subscriptionsKey = "cloudKitSubscriptionsDone"
    private static let subscriptionID = "cloudKitSharedDataSubscription"
    private static let sharedSubscriptionID = "cloudKitRemoteSharedDataSubscription"
    
    class func setupSharedSubscription() -> Promise<Int> {
        let subscription = CKDatabaseSubscription(subscriptionID: sharedSubscriptionID)
        let notificationInfo = CKNotificationInfo()
        notificationInfo.shouldSendContentAvailable = true
        subscription.notificationInfo = notificationInfo
        return CloudKitUtils.updateSubscriptions(subscriptions: [subscription], localDb: false)
    }
    
    class func setupSubscriptions() {
        if UserDefaults.standard.bool(forKey: subscriptionsKey) == false {
            all(setupSharedSubscription(), setupLocalSubscriptions()
                ).then({_ in
                    UserDefaults.standard.set(true, forKey: subscriptionsKey)
                })
        }
    }
    
    private class func setupLocalSubscriptions() -> Promise<Int> {
        let listsSubscription = createSubscription(forType: CloudKitUtils.listRecordType)
        let itemsSubscription = createSubscription(forType: CloudKitUtils.itemRecordType)
        return CloudKitUtils.updateSubscriptions(subscriptions: [listsSubscription, itemsSubscription], localDb: true)
    }
    
    private class func createSubscription(forType type: String) -> CKQuerySubscription {
        let predicate = NSPredicate(value: true)
        let subscription = CKQuerySubscription(recordType: type, predicate: predicate, subscriptionID: subscriptionID, options: [.firesOnRecordCreation, .firesOnRecordDeletion, .firesOnRecordUpdate])
        let notificationInfo = CKNotificationInfo()
        notificationInfo.shouldSendContentAvailable = true
        subscription.notificationInfo = notificationInfo
        return subscription
    }
}
