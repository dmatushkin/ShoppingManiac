//
//  AddCategoryViewController.swift
//  ShoppingManiac
//
//  Created by Dmitry Matyushkin on 21/05/2017.
//  Copyright © 2017 Dmitry Matyushkin. All rights reserved.
//

import UIKit
import CoreStore

class AddCategoryViewController: UIViewController {

    @IBOutlet weak var categoryNameEditField: UITextField!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.categoryNameEditField.text = self.category?.name
    }
    
    var category: Category?
    
    private func createItem(withName name: String) {
        CoreStore.beginSynchronous { (transaction) in
            let item = transaction.create(Into<Category>())
            item.name = name
            let _ = transaction.commit()
        }
    }
    
    private func updateItem(item: Category, withName name: String) {
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
        if identifier == "addCategorySaveSegue" {
            if let name = self.categoryNameEditField.text, name.characters.count > 0 {
                if let item = self.category {
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
