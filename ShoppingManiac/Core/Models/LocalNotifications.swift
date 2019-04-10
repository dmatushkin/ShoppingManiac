//
//  LocalNotifications.swift
//  ShoppingManiac
//
//  Created by Dmitry Matyushkin on 22/04/2018.
//  Copyright © 2018 Dmitry Matyushkin. All rights reserved.
//

import Foundation
import NoticeObserveKit

extension Notice.Names {
    static let keyboardWillChangeFrame = Notice.Name<UIKeyboardInfo>(UIResponder.keyboardWillChangeFrameNotification)
    static let keyboardWillHide = Notice.Name<UIKeyboardInfo>(UIResponder.keyboardWillHideNotification)
    static let newDataAvailable = Notice.Name<Bool>(Notification.Name(rawValue: "NewDataAvailable"))
}
