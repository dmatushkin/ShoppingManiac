//
//  CloudSubscriptions.swift
//  ShoppingManiac
//
//  Created by Dmitry Matyushkin on 28/04/2018.
//  Copyright © 2018 Dmitry Matyushkin. All rights reserved.
//

import Foundation
import CloudKit
import Combine
import CloudKitSync

class CloudSubscriptions {
    
    private static let cloudKitUtils = CloudKitSyncUtils()
    
    private init() {}
    
    private static let subscriptionsKey = "cloudKitSubscriptionsDone"
    private static let subscriptionID = "cloudKitSharedDataSubscription"
    private static let sharedSubscriptionID = "cloudKitRemoteSharedDataSubscription"
	private static var cancellables = Set<AnyCancellable>()
    
    class func setupSubscriptions() {
        if UserDefaults.standard.bool(forKey: subscriptionsKey) == false {
			setupSharedSubscription().merge(with: setupLocalSubscriptions()).sink(receiveCompletion: {completion in
				switch completion {
				case .finished:
					UserDefaults.standard.set(true, forKey: subscriptionsKey)
				case .failure:
					break
				}
			}, receiveValue: {}).store(in: &cancellables)
        }
    }
    
    private class func setupSharedSubscription() -> AnyPublisher<Void, Error> {
        let subscription = CKDatabaseSubscription(subscriptionID: sharedSubscriptionID)
        let notificationInfo = CKSubscription.NotificationInfo()
        notificationInfo.shouldSendContentAvailable = true
        subscription.notificationInfo = notificationInfo
        return cloudKitUtils.updateSubscriptions(subscriptions: [subscription], localDb: false)
    }
    
    private class func setupLocalSubscriptions() -> AnyPublisher<Void, Error> {
        let listsSubscription = createSubscription(forType: CloudKitShoppingList.recordType)
        let itemsSubscription = createSubscription(forType: CloudKitShoppingItem.recordType)
        return cloudKitUtils.updateSubscriptions(subscriptions: [listsSubscription, itemsSubscription], localDb: true)
    }
    
    private class func createSubscription(forType type: String) -> CKQuerySubscription {
        let predicate = NSPredicate(value: true)
        let subscription = CKQuerySubscription(recordType: type, predicate: predicate, subscriptionID: subscriptionID, options: [CKQuerySubscription.Options.firesOnRecordCreation, CKQuerySubscription.Options.firesOnRecordDeletion, CKQuerySubscription.Options.firesOnRecordUpdate])
        let notificationInfo = CKSubscription.NotificationInfo()
        notificationInfo.shouldSendContentAvailable = true
        subscription.notificationInfo = notificationInfo
        subscription.zoneID = CKRecordZone(zoneName: CloudKitShoppingList.zoneName).zoneID
        return subscription
    }
}
