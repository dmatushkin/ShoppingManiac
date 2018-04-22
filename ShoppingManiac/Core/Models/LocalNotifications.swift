//
//  LocalNotifications.swift
//  ShoppingManiac
//
//  Created by Dmitry Matyushkin on 22/04/2018.
//  Copyright © 2018 Dmitry Matyushkin. All rights reserved.
//

import Foundation
import NoticeObserveKit

struct NewDataAvailable: NoticeType {
    typealias InfoType = Bool
    static let name: Notification.Name = Notification.Name(rawValue: "NewDataAvailable")
}
