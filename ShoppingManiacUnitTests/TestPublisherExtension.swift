//
//  PublisherExtension.swift
//  ShoppingManiacUnitTests
//
//  Created by Dmitry Matyushkin on 7/22/20.
//  Copyright © 2020 Dmitry Matyushkin. All rights reserved.
//

import Combine
import XCTest

extension Publisher {

	func getValue(test: XCTestCase, timeout: TimeInterval) throws -> Self.Output {
		var result: Self.Output?
		var failure: Self.Failure?
		let exp = test.expectation(description: "wait for values")
		let cancellable = self.sink(receiveCompletion: { completion in
			switch completion {
			case .finished:
				exp.fulfill()
			case .failure(let error):
				failure = error
				exp.fulfill()
			}
		}, receiveValue: {output in
			result = output
		})
		test.wait(for: [exp], timeout: timeout)
		if let error = failure {
			throw error
		}
		guard let out = result else { fatalError() }
		_ = cancellable
		return out
	}

	func wait(test: XCTestCase, timeout: TimeInterval) throws {
		var failure: Self.Failure?
		let exp = test.expectation(description: "wait for completion")
		let cancellable = self.sink(receiveCompletion: { completion in
			switch completion {
			case .finished:
				exp.fulfill()
			case .failure(let error):
				failure = error
				exp.fulfill()
			}
		}, receiveValue: {_ in
		})
		test.wait(for: [exp], timeout: timeout)
		if let error = failure {
			throw error
		}
		_ = cancellable
	}
}
