//
//  CloudLoaderUnitTests.swift
//  ShoppingManiacUnitTests
//
//  Created by Dmitry Matyushkin on 2/1/20.
//  Copyright © 2020 Dmitry Matyushkin. All rights reserved.
//

import XCTest

class CloudLoaderUnitTests: XCTestCase {
    
    private let utilsStub = CloudKitUtilsStub()
    private var cloudLoader: CloudLoader!
    
    override func setUp() {
        self.cloudLoader = CloudLoader(cloudKitUtils: self.utilsStub)
        self.utilsStub.cleanup()
        TestDbWrapper.setup()
    }

    override func tearDown() {
        self.cloudLoader = nil
        self.utilsStub.cleanup()
        TestDbWrapper.cleanup()
    }

    func testExample() {
        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct results.
    }
}
