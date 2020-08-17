//
//  AddCategoryViewController.swift
//  ShoppingManiac
//
//  Created by Dmitry Matyushkin on 21/05/2017.
//  Copyright © 2017 Dmitry Matyushkin. All rights reserved.
//

import UIKit
import CoreStore
import Combine
import CommonError

class AddCategoryViewController: ShoppingManiacViewController {

    @IBOutlet private weak var categoryNameEditField: UITextField!
    
    let model = AddCategoryModel()

    override func viewDidLoad() {
        super.viewDidLoad()
		self.categoryNameEditField.bind(to: self.model.categoryName, store: &self.model.cancellables)
        self.categoryNameEditField.becomeFirstResponder()
        self.model.applyData()
    }

	@IBAction private func saveAction() {
		guard let value = self.model.categoryName.value, value.count > 0 else {
			CommonError(description: "Category name should not be empty").showError(title: "Unable to create category")
			return
		}
		self.model.persistDataAsync().observeOnMain().sink(receiveCompletion: {completion in
			switch completion {
			case .finished:
				break
			case .failure(let error):
				error.showError(title: "Unable to create category")
			}
		}, receiveValue: {[weak self] in
			self?.performSegue(withIdentifier: "addCategorySaveSegue", sender: nil)
		}).store(in: &self.model.cancellables)
	}
}
