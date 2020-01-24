//
//  CloudKitTestOperations.swift
//  ShoppingManiacUnitTests
//
//  Created by Dmitry Matyushkin on 1/24/20.
//  Copyright © 2020 Dmitry Matyushkin. All rights reserved.
//

import Foundation
import CloudKit

class CloudKitTestOperations: CloudKitOperationsProtocol {
    
    private let operationsQueue = DispatchQueue(label: "CloudKitTestOperations.operationsQueue", attributes: .concurrent)
    
    var localOperations: [CKDatabaseOperation] = []
    var sharedOperations: [CKDatabaseOperation] = []
    var onAddOperation: ((CKDatabaseOperation, [CKDatabaseOperation], [CKDatabaseOperation]) -> Void)?
    
    func cleanup() {
        self.localOperations = []
        self.sharedOperations = []
        self.onAddOperation = nil
    }
    
    func run(operation: CKDatabaseOperation, localDb: Bool) {
        if localDb {
            localOperations.append(operation)
        } else {
            sharedOperations.append(operation)
        }
        self.operationsQueue.async {[weak self] in
            guard let self = self else { return }
            self.onAddOperation?(operation, self.localOperations, self.sharedOperations)
        }        
    }
}
