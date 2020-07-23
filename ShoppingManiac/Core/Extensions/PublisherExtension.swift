//
//  PublisherExtension.swift
//  ShoppingManiac
//
//  Created by Dmitry Matyushkin on 7/23/20.
//  Copyright © 2020 Dmitry Matyushkin. All rights reserved.
//

import Combine
import Foundation

extension Publisher {

	func observeOnMain() ->  AnyPublisher<Self.Output, Self.Failure> {
		return receive(on: DispatchQueue.main).eraseToAnyPublisher()
	}
}
