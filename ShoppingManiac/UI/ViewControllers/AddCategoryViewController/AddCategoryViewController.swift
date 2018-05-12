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
    
    let model = AddCategoryModel()

    override func viewDidLoad() {
        super.viewDidLoad()
        (self.categoryNameEditField.rx.text.orEmpty <-> self.model.categoryName).disposed(by: self.model.disposeBag)
        self.categoryNameEditField.becomeFirstResponder()
        self.model.applyData()
    }

    // MARK: - Navigation

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
    }

    override func shouldPerformSegue(withIdentifier identifier: String, sender: Any?) -> Bool {
        if identifier == "addCategorySaveSegue" {
            if self.model.categoryName.value.count > 0 {
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
