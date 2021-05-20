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
    @IBOutlet private weak var goodsTableView: UITableView!
    
    let model = AddCategoryModel()

    override func viewDidLoad() {
        super.viewDidLoad()
		self.categoryNameEditField.bind(to: self.model.categoryName, store: &self.model.cancellables)
        self.categoryNameEditField.becomeFirstResponder()
        self.model.applyData()
        self.goodsTableView.dataSource = self.model.dataSource
        self.goodsTableView.delegate = self.model.dataHandler
        self.goodsTableView.layer.cornerRadius = 5
        self.goodsTableView.clipsToBounds = true
        self.model.needsTableReload = {[weak self] in
            self?.goodsTableView.reloadData()
        }
    }

	@IBAction private func saveAction() {
        guard let value = self.model.categoryName.value, !value.isEmpty else {
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
    
    @IBAction private func addGood(unwindSegue: UIStoryboardSegue) {
        if unwindSegue.identifier == "addGoodToCategorySegue", let value = (unwindSegue.source as? AddGoodToCategoryViewController)?.value {
            self.model.appendGood(name: value)
        }
    }
}
