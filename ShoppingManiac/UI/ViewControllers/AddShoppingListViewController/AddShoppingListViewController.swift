//
//  AddShoppingListViewController.swift
//  ShoppingManiac
//
//  Created by Dmitry Matyushkin on 21/05/2017.
//  Copyright © 2017 Dmitry Matyushkin. All rights reserved.
//

import UIKit
import CoreStore

class AddShoppingListViewController: ShoppingManiacViewController {

    @IBOutlet weak var shoppingNameEditField: UITextField!
    var shoppingList: ShoppingList?

    override func viewDidLoad() {
        super.viewDidLoad()
        self.shoppingNameEditField.becomeFirstResponder()
    }

    private func createItem(withName name: String) -> ShoppingList? {
        do {
            let list: ShoppingList = try CoreStore.perform(synchronous: { transaction in
                let item = transaction.create(Into<ShoppingList>())
                item.name = name
                item.date = Date().timeIntervalSinceReferenceDate
                return item
            })
            return CoreStore.fetchExisting(list)
        } catch {
            return nil
        }
    }

    // MARK: - Navigation

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "addListSaveSegue", let name = self.shoppingNameEditField.text, let list = self.createItem(withName: name) {
            (segue.destination as? ShoppingListViewController)?.shoppingList = list
        }
    }
}
