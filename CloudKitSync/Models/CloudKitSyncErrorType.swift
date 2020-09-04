//
//  CloudKitSyncErrorType.swift
//  CloudKitSync
//
//  Created by Dmitry Matyushkin on 8/14/20.
//  Copyright © 2020 Dmitry Matyushkin. All rights reserved.
//

import Foundation
import CloudKit
import CommonError

enum CloudKitSyncErrorType {
	case failure(error: Error)
	case retry(timeout: Double)
	case tokenReset
	case noError

	static func errorType(forError error: Error?) -> CloudKitSyncErrorType {
		guard let error = error else { return .noError }
        if let localError = error as? CommonError {
            return testErrorType(forError: localError)
        }
		guard let ckError = error as? CKError else {
			return .failure(error: error)
		}
		switch ckError.code {
		case .serviceUnavailable, .requestRateLimited, .zoneBusy:
			let retry = ckError.retryAfterSeconds ?? (ckError.userInfo[CKErrorRetryAfterKey] as? Double) ?? 3
			return .retry(timeout: retry)
		case .changeTokenExpired:
			return .tokenReset
		default:
			return .failure(error: error)
		}
	}

    private static func testErrorType(forError error: CommonError) -> CloudKitSyncErrorType {
        if error.errorDescription == "retry" {
            return .retry(timeout: 1)
        } else if error.errorDescription == "token" {
            return .tokenReset
        } else {
            return .failure(error: error)
        }
    }
}
