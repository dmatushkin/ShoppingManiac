//
//  CommonError.swift
//  ShoppingManiac
//
//  Created by Dmitry Matyushkin on 22/04/2018.
//  Copyright © 2018 Dmitry Matyushkin. All rights reserved.
//

import Foundation
import SwiftyBeaver

public class CommonError: LocalizedError {
    
    private let description: String
    
    public init(description: String) {
        self.description = description
    }
    
    public var errorDescription: String? {
        return self.description
    }

	public class func logDebug(_ text: String) {
		SwiftyBeaver.debug(text)
	}

	public static func logError(_ text: String) {
		SwiftyBeaver.error(text)
	}
}

public extension Error {
    
    func log() {
		CommonError.logError(self.localizedDescription)
    }
}
