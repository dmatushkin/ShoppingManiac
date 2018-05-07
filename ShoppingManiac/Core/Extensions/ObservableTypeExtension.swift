//
//  ObservableTypeExtension.swift
//  ShoppingManiac
//
//  Created by Dmitry Matyushkin on 07/05/2018.
//  Copyright © 2018 Dmitry Matyushkin. All rights reserved.
//

import Foundation
import RxSwift

extension ObservableType {
    
    public func observeOnMain() -> RxSwift.Observable<Self.E> {
        return self.observeOn(MainScheduler.asyncInstance)
    }
}
