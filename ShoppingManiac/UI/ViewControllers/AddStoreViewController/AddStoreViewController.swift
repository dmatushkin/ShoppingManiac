//
//  AddStoreViewController.swift
//  ShoppingManiac
//
//  Created by Dmitry Matyushkin on 21/05/2017.
//  Copyright © 2017 Dmitry Matyushkin. All rights reserved.
//

import UIKit
import CoreStore

class AddStoreViewController: UIViewController {

    @IBOutlet weak var storeNameEditField: UITextField!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.storeNameEditField.text = self.store?.name
    }
    
    var store: Store?
    
    private func createItem(withName name: String) {
        CoreStore.beginSynchronous { (transaction) in
            let item = transaction.create(Into<Store>())
            item.name = name
            let _ = transaction.commit()
        }
    }
    
    private func updateItem(item: Store, withName name: String) {
        CoreStore.beginSynchronous { (transaction) in
            let item = transaction.edit(item)
            item?.name = name
            let _ = transaction.commit()
        }
    }
    
    // MARK: - Navigation
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
    }
    
    override func shouldPerformSegue(withIdentifier identifier: String, sender: Any?) -> Bool {
        if identifier == "addStoreSaveSegue" {
            if let name = self.storeNameEditField.text, name.characters.count > 0 {
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
