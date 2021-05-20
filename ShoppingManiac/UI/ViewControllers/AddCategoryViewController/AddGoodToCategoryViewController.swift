//
//  AddGoodToCategoryViewController.swift
//  ShoppingManiac
//
//  Created by Dmitry Matyushkin on 20.05.2021.
//  Copyright © 2021 Dmitry Matyushkin. All rights reserved.
//

import UIKit
import CommonError

class AddGoodToCategoryViewController: UIViewController {

    @IBOutlet private weak var goodNameField: AutocompleteTextField!
    
    private let model = AddGoodToCategoryModel()
    
    var value: String? {
        return self.goodNameField.text?.nilIfEmpty
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        self.goodNameField.autocompleteStrings = model.listAllGoods()
        self.goodNameField.becomeFirstResponder()
        self.preferredContentSize = self.view.systemLayoutSizeFitting(UIView.layoutFittingCompressedSize)
    }
    
    @IBAction private func addGoodAction() {
        guard self.value != nil else {
            CommonError(description: "Good name should not be empty").showError(title: "Unable to add good")
            return
        }
        self.performSegue(withIdentifier: "addGoodToCategorySegue", sender: nil)
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
