//
//  DIProvider.swift
//  ShoppingManiac
//
//  Created by Dmitry Matyushkin on 7/22/20.
//  Copyright © 2020 Dmitry Matyushkin. All rights reserved.
//

import Foundation

protocol DIDependency {
	init()
}

class DIProvider {

	enum DIRegistrationType {
		case dependency(type: DIDependency.Type)
		case lambda(value: () -> Any)
	}

	private init() {}

	static let shared = DIProvider()

	private var diMap: [String: DIRegistrationType] = [:]

	func inject(forType type: Any) -> Any? {
		let className = String(describing: type.self)
		guard let registration = diMap[className] else { return nil }
		switch registration {
		case .dependency(let type):
			return type.init()
		case .lambda(let value):
			return value()
		}
	}

	@discardableResult
	func register(forType type: Any, lambda: @escaping () -> Any) -> DIProvider {
		let className = String(describing: type.self)
		diMap[className] = .lambda(value: lambda)
		return self
	}

	@discardableResult
	func register(forType type: Any, dependency: DIDependency.Type) -> DIProvider {
		let className = String(describing: type.self)
		diMap[className] = .dependency(type: dependency)
		return self
	}

	func clear() {
		diMap = [:]
	}
}
