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
    let animationCurve: UIView.AnimationOptions
    let keyboardIsHidden: Bool

    init(info: [AnyHashable: Any]) {
        let frame = (info[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue)?.cgRectValue ?? CGRect.zero
        let duration = info[UIResponder.keyboardAnimationDurationUserInfoKey] as? TimeInterval ?? 0
        let curve = (info[UIResponder.keyboardAnimationCurveUserInfoKey] as? UInt) ?? 0
        self.frame = frame
        self.animationDuration = duration
        self.animationCurve = UIView.AnimationOptions(rawValue: curve)
        self.keyboardIsHidden = frame.size.height == 0
    }
}
