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
    @IBOutlet private weak var categoriesTable: UITableView!

    let model = AddStoreModel()

    override func viewDidLoad() {
        super.viewDidLoad()
		self.storeNameEditField.bind(to: self.model.storeName, store: &self.model.cancellables)
        self.storeNameEditField.becomeFirstResponder()
        self.model.applyData()
        self.categoriesTable.dataSource = self.model.dataSource
        self.categoriesTable.delegate = self.model.dataHandler
        self.categoriesTable.layer.cornerRadius = 5
        self.categoriesTable.clipsToBounds = true
        self.model.needsTableReload = {[weak self] in
            self?.categoriesTable.reloadData()
        }
        self.categoriesTable.isEditing = true
    }

	@IBAction private func saveAction() {
        guard let value = self.model.storeName.value, !value.isEmpty else {
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
    
    @IBAction private func addCategory(unwindSegue: UIStoryboardSegue) {
        if unwindSegue.identifier == "addCategoryToStoreSegue", let value = (unwindSegue.source as? AddCategoryToStoreViewController)?.value {
            self.model.appendCategory(name: value)
        }
    }
}
