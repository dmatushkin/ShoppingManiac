//
//  AddStoreViewController.swift
//  ShoppingManiac
//
//  Created by Dmitry Matyushkin on 21/05/2017.
//  Copyright © 2017 Dmitry Matyushkin. All rights reserved.
//

import UIKit
import CoreStore
import Combine
import CommonError

class AddStoreViewController: ShoppingManiacViewController {

    @IBOutlet private weak var storeNameEditField: UITextField!

    let model = AddStoreModel()

    override func viewDidLoad() {
        super.viewDidLoad()
		self.storeNameEditField.bind(to: self.model.storeName, store: &self.model.cancellables)
        self.storeNameEditField.becomeFirstResponder()
        self.model.applyData()
    }

	@IBAction private func saveAction() {
		guard let value = self.model.storeName.value, value.count > 0 else {
			CommonError(description: "Store name should not be empty").showError(title: "Unable to create store")
			return
		}
		self.model.persistDataAsync().observeOnMain().sink(receiveCompletion: {completion in
			switch completion {
			case .finished:
				break
			case .failure(let error):
				error.showError(title: "Unable to create store")
			}
		}, receiveValue: {[weak self] in
			self?.performSegue(withIdentifier: "addStoreSaveSegue", sender: nil)
		}).store(in: &model.cancellables)
	}
}
