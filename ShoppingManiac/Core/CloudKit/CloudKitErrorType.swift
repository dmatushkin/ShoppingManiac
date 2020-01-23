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
	
	static func errorType(forError error: Error) -> CloudKitErrorType {
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
}
