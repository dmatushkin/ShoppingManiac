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

    @IBOutlet weak var storeNameEditField: UITextField!

    override func viewDidLoad() {
        super.viewDidLoad()
        self.storeNameEditField.text = self.store?.name
        self.storeNameEditField.becomeFirstResponder()
    }

    var store: Store?

    private func createItem(withName name: String) {
        try? CoreStore.perform(synchronous: { transaction in
            let item = transaction.create(Into<Store>())
            item.name = name
        })
    }

    private func updateItem(item: Store, withName name: String) {
        try? CoreStore.perform(synchronous: { transaction in
            let item = transaction.edit(item)
            item?.name = name
        })
    }

    // MARK: - Navigation

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
    }

    override func shouldPerformSegue(withIdentifier identifier: String, sender: Any?) -> Bool {
        if identifier == "addStoreSaveSegue" {
            if let name = self.storeNameEditField.text, name.count > 0 {
                if let item = self.store {
                    self.updateItem(item: item, withName: name)
                } else {
                    self.createItem(withName: name)
                }
                return true
            } else {
                return false
            }
        } else {
            return true
        }
    }
}
