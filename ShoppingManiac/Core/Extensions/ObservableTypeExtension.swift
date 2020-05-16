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
import CoreStore
import CoreData

infix operator <->

func <-> <T>(property: ControlProperty<T>, variable: BehaviorRelay<T>) -> Disposable {
    let bindToUIDisposable = variable.asObservable()
        .bind(to: property)
    let bindToVariable = property
        .subscribe(onNext: { next in
            variable.accept(next)
        }, onCompleted: {
            bindToUIDisposable.dispose()
        })
    return CompositeDisposable(bindToUIDisposable, bindToVariable)
}

extension ObservableType {
    
    public func observeOnMain() -> RxSwift.Observable<Self.Element> {
        return self.observeOn(MainScheduler.asyncInstance)
    }
}

extension AnyObserver {

	func processResult(result: Result<Element, CoreStoreError>) {
		switch result {
		case .success(let element):
			if let coreDataObject = (element as? NSManagedObject).flatMap({ CoreStoreDefaults.dataStack.fetchExisting($0) }).flatMap({ $0 as? Element }) {
				self.onNext(coreDataObject)
			} else {
				self.onNext(element)
			}
			self.onCompleted()
		case .failure(let error):
			self.onError(error)
		}
	}
}

extension Observable {
	static func performCoreStore(_ operation: @escaping ((AsynchronousDataTransaction) throws -> Element)) -> Observable {
		return Observable<Element>.create { observer in
			CoreStoreDefaults.dataStack.perform(asynchronous: operation, completion: {result in
				observer.processResult(result: result)
			})
			return Disposables.create()
		}
	}
}
