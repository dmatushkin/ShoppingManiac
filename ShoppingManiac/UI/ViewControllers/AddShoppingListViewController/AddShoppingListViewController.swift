//
//  AddShoppingListViewController.swift
//  ShoppingManiac
//
//  Created by Dmitry Matyushkin on 21/05/2017.
//  Copyright © 2017 Dmitry Matyushkin. All rights reserved.
//

import UIKit
import CoreStore

class AddShoppingListViewController: UIViewController {

    @IBOutlet weak var shoppingNameEditField: UITextField!
    var shoppingList: ShoppingList?
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.shoppingNameEditField.becomeFirstResponder()
    }

    private func createItem(withName name: String) {
        CoreStore.beginSynchronous { (transaction) in
            let item = transaction.create(Into<ShoppingList>())
            item.name = name
            item.date = Date().timeIntervalSince1970
            let _ = transaction.commit()
        }
    }
    
    // MARK: - Navigation

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "addListSaveSegue", let name = self.shoppingNameEditField.text {
            self.createItem(withName: name)
        }
    }
}
