//
//  DataSaveSegue.swift
//  ShoppingManiac
//
//  Created by Dmitry Matyushkin on 19/12/2017.
//  Copyright © 2017 Dmitry Matyushkin. All rights reserved.
//

import UIKit
import CoreStore

class DataSaveSegue: UIStoryboardSegue {

    var errorMessage: String?
    var processBlock: (AsynchronousDataTransaction) -> Bool = {transaction in return true}

    override func perform() {
        CoreStore.perform(asynchronous: {transaction->Bool in
            return self.processBlock(transaction)
        }, completion: { result in
            if result.boolValue {
                self.realPerform()
            } else {
                self.showAlert(message: self.errorMessage ?? "Error saving data")
            }
        })
    }

    private func realPerform() {
        super.perform()
    }

    private func showAlert(message: String) {
        let alert = UIAlertController(title: "Error", message: message, preferredStyle: .alert)
        let closeAction = UIAlertAction(title: "Close", style: .cancel) { [weak alert] _ in
            alert?.dismiss(animated: true, completion: nil)
        }
        alert.addAction(closeAction)
        self.source.present(alert, animated: true, completion: nil)
    }
}
