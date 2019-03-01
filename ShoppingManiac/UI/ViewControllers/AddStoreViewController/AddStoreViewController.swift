//
//  AddStoreViewController.swift
//  ShoppingManiac
//
//  Created by Dmitry Matyushkin on 21/05/2017.
//  Copyright © 2017 Dmitry Matyushkin. All rights reserved.
//

import UIKit
import CoreStore

class AddStoreViewController: ShoppingManiacViewController {

    @IBOutlet private weak var storeNameEditField: UITextField!

    let model = AddStoreModel()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        (self.storeNameEditField.rx.text.orEmpty <-> self.model.storeName).disposed(by: self.model.disposeBag)
        self.storeNameEditField.becomeFirstResponder()
        self.model.applyData()
    }

    // MARK: - Navigation

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
    }

    override func shouldPerformSegue(withIdentifier identifier: String, sender: Any?) -> Bool {
        if identifier == "addStoreSaveSegue" {
            if self.model.storeName.value.count > 0 {
                self.model.persistData()
                return true
            } else {
                return false
            }
        } else {
            return true
        }
    }
}
