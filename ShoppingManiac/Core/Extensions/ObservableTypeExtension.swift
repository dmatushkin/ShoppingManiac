//
//  ObservableTypeExtension.swift
//  ShoppingManiac
//
//  Created by Dmitry Matyushkin on 07/05/2018.
//  Copyright © 2018 Dmitry Matyushkin. All rights reserved.
//

import Foundation
import RxSwift
import RxCocoa

infix operator <->

func <-> <T>(property: ControlProperty<T>, variable: Variable<T>) -> Disposable {
    let bindToUIDisposable = variable.asObservable()
        .bind(to: property)
    let bindToVariable = property
        .subscribe(onNext: { next in
            variable.value = next
        }, onCompleted: {
            bindToUIDisposable.dispose()
        })
    return CompositeDisposable(bindToUIDisposable, bindToVariable)
}

extension ObservableType {
    
    public func observeOnMain() -> RxSwift.Observable<Self.E> {
        return self.observeOn(MainScheduler.asyncInstance)
    }
}
