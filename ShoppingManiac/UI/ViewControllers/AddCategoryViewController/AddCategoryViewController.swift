//
//  AddCategoryViewController.swift
//  ShoppingManiac
//
//  Created by Dmitry Matyushkin on 21/05/2017.
//  Copyright © 2017 Dmitry Matyushkin. All rights reserved.
//

import UIKit
import CoreStore

class AddCategoryViewController: ShoppingManiacViewController {

    @IBOutlet weak var categoryNameEditField: UITextField!

    override func viewDidLoad() {
        super.viewDidLoad()
        self.categoryNameEditField.text = self.category?.name
        self.categoryNameEditField.becomeFirstResponder()
    }

    var category: Category?

    private func createItem(withName name: String) {
        try? CoreStore.perform(synchronous: { transaction in
            let item = transaction.create(Into<Category>())
            item.name = name
        })
    }

    private func updateItem(item: Category, withName name: String) {
        try? CoreStore.perform(synchronous: { transaction in
            let item = transaction.edit(item)
            item?.name = name
        })
    }

    // MARK: - Navigation

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
    }

    override func shouldPerformSegue(withIdentifier identifier: String, sender: Any?) -> Bool {
        if identifier == "addCategorySaveSegue" {
            if let name = self.categoryNameEditField.text, name.count > 0 {
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
