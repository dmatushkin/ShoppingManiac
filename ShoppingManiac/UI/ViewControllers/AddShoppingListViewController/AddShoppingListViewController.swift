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

    private func createItem(withName name: String) -> ShoppingList {
        var listId: NSManagedObjectID!
        CoreStore.beginSynchronous { (transaction) in
            let item = transaction.create(Into<ShoppingList>())
            item.name = name
            item.date = Date().timeIntervalSinceReferenceDate
            let _ = transaction.commit()
            listId = item.objectID
        }
        return CoreStore.fetchExisting(listId) as! ShoppingList
    }
    
    // MARK: - Navigation

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "addListSaveSegue", let name = self.shoppingNameEditField.text {
            let list = self.createItem(withName: name)
            (segue.destination as? ShoppingListsListViewController)?.listToShow = list
        }
    }
}
