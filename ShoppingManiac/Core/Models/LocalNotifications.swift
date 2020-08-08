//
//  LocalNotifications.swift
//  ShoppingManiac
//
//  Created by Dmitry Matyushkin on 22/04/2018.
//  Copyright © 2018 Dmitry Matyushkin. All rights reserved.
//

import UIKit
import Combine

class LocalNotification<T> {
    private let subject = PassthroughSubject<T, Never>()
    fileprivate var observer: NSObjectProtocol?
    
    init() {
    }
    
    deinit {
        if let observer = self.observer {
            NotificationCenter.default.removeObserver(observer)
        }
    }
    
    func post(value: T) {
        self.subject.send(value)
    }
    
    func listen() -> AnyPublisher<T, Never> {
        return self.subject.observeOnMain()
    }
}

extension LocalNotification where T: NotificationUserInfoDecodable {
    
    convenience init(notificationName: Notification.Name) {
        self.init()
        self.observer = NotificationCenter.default.addObserver(forName: notificationName, object: nil, queue: nil, using: self.notificationAction)
    }
    
    private func notificationAction(notification: Notification) {
        if let info = notification.userInfo, let obj = T(info: info) {
            self.subject.send(obj)
        }
    }
}

struct LocalNotifications {
    private init() {}
    
    static let keyboardWillChangeFrame = LocalNotification<UIKeyboardInfo>(notificationName: UIResponder.keyboardWillChangeFrameNotification)
    static let keyboardWillHide = LocalNotification<UIKeyboardInfo>(notificationName: UIResponder.keyboardWillHideNotification)
}
