//
//  CloudKitErrorType.swift
//  ShoppingManiac
//
//  Created by Dmitry Matyushkin on 1/23/20.
//  Copyright © 2020 Dmitry Matyushkin. All rights reserved.
//

import Foundation
import CloudKit

enum CloudKitErrorType {
	case failure(error: Error)
	case retry(timeout: Double)
	case tokenReset
	case noError
	
	static func errorType(forError error: Error?) -> CloudKitErrorType {
		guard let error = error else { return .noError }
        if let localError = error as? CommonError {
            return testErrorType(forError: localError)
        }
		guard let ckError = error as? CKError else {
			return .failure(error: error)
		}
		switch ckError.code {
		case .serviceUnavailable, .requestRateLimited, .zoneBusy:
			if let retry = ckError.userInfo[CKErrorRetryAfterKey] as? Double {
				return .retry(timeout: retry)
			} else {
				return .failure(error: error)
			}
		case .changeTokenExpired:
			return .tokenReset
		default:
			return .failure(error: error)
		}
	}
    
    private static func testErrorType(forError error: CommonError) -> CloudKitErrorType {
        if error.errorDescription == "retry" {
            return .retry(timeout: 1)
        } else if error.errorDescription == "token" {
            return .tokenReset
        } else {
            return .failure(error: error)
        }
    }
}
