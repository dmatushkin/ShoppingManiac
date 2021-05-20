//
//  AddCategoryToStoreViewController.swift
//  ShoppingManiac
//
//  Created by Dmitry Matyushkin on 19.05.2021.
//  Copyright © 2021 Dmitry Matyushkin. All rights reserved.
//

import UIKit
import CommonError

class AddCategoryToStoreViewController: UIViewController {
    
    @IBOutlet private weak var categoryNameField: AutocompleteTextField!
    
    private let model = AddCategoryToStoreModel()
    
    var value: String? {
        return self.categoryNameField.text?.nilIfEmpty
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        self.categoryNameField.autocompleteStrings = model.listAllCategories()
        self.categoryNameField.becomeFirstResponder()
    }
    
    @IBAction private func addCategoryAction() {
        guard self.value != nil else {
            CommonError(description: "Category name should not be empty").showError(title: "Unable to add category")
            return
        }
        self.performSegue(withIdentifier: "addCategoryToStoreSegue", sender: nil)
    }
    
    @IBAction private func cancelAction() {
        self.dismiss(animated: true, completion: nil)
    }
    
    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destination.
        // Pass the selected object to the new view controller.
    }
    */

}
