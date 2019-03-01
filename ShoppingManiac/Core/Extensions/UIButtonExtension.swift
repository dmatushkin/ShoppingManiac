//
//  UIButtonExtension.swift
//  ShoppingManiac
//
//  Created by Dmitry Matyushkin on 12/05/2018.
//  Copyright © 2018 Dmitry Matyushkin. All rights reserved.
//

import UIKit
import RxCocoa
import RxSwift

extension UIButton {
    
    func tagRatingBinding(variable: Variable<Int>) -> Disposable {
        let bindToUIDisposable = variable.asObservable().subscribe(onNext: {[weak self] rating in
            guard let `self` = self else {return}
            self.isSelected = (self.tag <= rating)
        })
        let bindToVariable = self.rx.tap.map({[weak self] in self?.tag ?? 0})
            .subscribe(onNext: { next in
                variable.value = next
            }, onCompleted: {
                bindToUIDisposable.dispose()
            })
        return CompositeDisposable(bindToUIDisposable, bindToVariable)
    }
}
