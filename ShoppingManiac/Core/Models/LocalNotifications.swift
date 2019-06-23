//
//  LocalNotifications.swift
//  ShoppingManiac
//
//  Created by Dmitry Matyushkin on 22/04/2018.
//  Copyright © 2018 Dmitry Matyushkin. All rights reserved.
//

import Foundation
import RxSwift
import RxCocoa

class LocalNotification<T> {
    private let subject = PublishSubject<T>()
    fileprivate var observer: NSObjectProtocol?
    
    init() {
    }
    
    deinit {
        if let observer = self.observer {
            NotificationCenter.default.removeObserver(observer)
        }
    }
    
    func post(value: T) {
        self.subject.onNext(value)
    }
    
    func listen() -> Observable<T> {
        return self.subject.asObservable().observeOn(MainScheduler.asyncInstance)
    }
}

extension LocalNotification where T: NotificationUserInfoDecodable {
    
    convenience init(notificationName: Notification.Name) {
        self.init()
        self.observer = NotificationCenter.default.addObserver(forName: notificationName, object: nil, queue: nil, using: self.notificationAction)
    }
    
    private func notificationAction(notification: Notification) {
        if let info = notification.userInfo, let obj = T(info: info) {
            self.subject.onNext(obj)
        }
    }
}

struct LocalNotifications {
    private init() {}
    
    static let keyboardWillChangeFrame = LocalNotification<UIKeyboardInfo>(notificationName: UIResponder.keyboardWillChangeFrameNotification)
    static let keyboardWillHide = LocalNotification<UIKeyboardInfo>(notificationName: UIResponder.keyboardWillHideNotification)
    static let newDataAvailable = LocalNotification<Void>()
}
