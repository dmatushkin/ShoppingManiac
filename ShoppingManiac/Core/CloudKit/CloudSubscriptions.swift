//
//  CloudSubscriptions.swift
//  ShoppingManiac
//
//  Created by Dmitry Matyushkin on 28/04/2018.
//  Copyright © 2018 Dmitry Matyushkin. All rights reserved.
//

import Foundation
import CloudKit
import RxSwift

class CloudSubscriptions {
    
    private static let subscriptionsKey = "cloudKitSubscriptionsDone"
    private static let subscriptionID = "cloudKitSharedDataSubscription"
    private static let sharedSubscriptionID = "cloudKitRemoteSharedDataSubscription"
    
    class func setupSubscriptions() {
        if UserDefaults.standard.bool(forKey: subscriptionsKey) == false {
            _ = Observable.of(setupSharedSubscription(), setupLocalSubscriptions()).merge().subscribe(onCompleted: {
                UserDefaults.standard.set(true, forKey: subscriptionsKey)
            })
        }
    }
    
    private class func setupSharedSubscription() -> Observable<Void> {
        let subscription = CKDatabaseSubscription(subscriptionID: sharedSubscriptionID)
        let notificationInfo = CKNotificationInfo()
        notificationInfo.shouldSendContentAvailable = true
        subscription.notificationInfo = notificationInfo
        return CloudKitUtils.updateSubscriptions(subscriptions: [subscription], localDb: false)
    }
    
    private class func setupLocalSubscriptions() -> Observable<Void> {
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
