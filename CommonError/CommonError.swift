//
//  CommonError.swift
//  ShoppingManiac
//
//  Created by Dmitry Matyushkin on 22/04/2018.
//  Copyright © 2018 Dmitry Matyushkin. All rights reserved.
//

import Foundation
import SwiftyBeaver
import CloudKit

public class CommonError: LocalizedError {
    
    private let description: String
    
    public init(description: String) {
        self.description = description
    }
    
    public var errorDescription: String? {
        return self.description
    }

	public class func logDebug(_ text: String, file: String = #file, function: String = #function, line: Int = #line) {
		SwiftyBeaver.debug(text, file, function, line: line)
	}

	public static func logError(_ text: String, file: String = #file, function: String = #function, line: Int = #line) {
		SwiftyBeaver.error(text, file, function, line: line)
	}
}

public extension Error {
    
	func log(file: String = #file, line: Int = #line, function: String = #function) {
		if let ckError = self as? CKError {
			let serverRecord = String(describing: ckError.serverRecord)
			let clientRecord = String(describing: ckError.clientRecord)
			let ancestorRecord = String(describing: ckError.ancestorRecord)
			let partialErrors = String(describing: ckError.partialErrorsByItemID)
			let additionalDescription = "Error code \(ckError.code.rawValue), serverRecord \(serverRecord), clientRecord \(clientRecord), ancestorRecord \(ancestorRecord), partialErrors \(partialErrors)\n"
			CommonError.logError(self.localizedDescription + "\nAdditional: " + additionalDescription, file: file, function: function, line: line)
		} else {
			CommonError.logError(self.localizedDescription, file: file, function: function, line: line)
		}
    }
}
