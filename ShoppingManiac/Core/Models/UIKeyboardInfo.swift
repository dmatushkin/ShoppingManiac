//
//  UIKeyboardInfo.swift
//  ShoppingManiac
//
//  Created by Dmitry Matyushkin on 10/20/17.
//  Copyright © 2017 Dmitry Matyushkin. All rights reserved.
//

import Foundation
import NoticeObserveKit

struct UIKeyboardInfo: NoticeUserInfoDecodable {
    let frame: CGRect
    let animationDuration: TimeInterval
    let animationCurve: UIViewAnimationOptions
    let keyboardIsHidden: Bool
    
    init(info: [AnyHashable : Any]) {
        let frame = (info[UIKeyboardFrameEndUserInfoKey] as? NSValue)?.cgRectValue ?? CGRect.zero
        let duration = info[UIKeyboardAnimationDurationUserInfoKey] as? TimeInterval ?? 0
        let curve = (info[UIKeyboardAnimationCurveUserInfoKey] as? UInt) ?? 0
        self.frame = frame
        self.animationDuration = duration
        self.animationCurve = UIViewAnimationOptions(rawValue: curve)
        self.keyboardIsHidden = frame.size.height == 0
    }
}

struct UIKeyboardWillChangeFrame: NoticeType {
    typealias InfoType = UIKeyboardInfo
    static let name: Notification.Name = .UIKeyboardWillChangeFrame
}

struct UIKeyboardWillHide: NoticeType {
    typealias InfoType = UIKeyboardInfo
    static let name: Notification.Name = .UIKeyboardWillHide
}
