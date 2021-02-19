//
//  AddShoppingItemViewController.swift
//  ShoppingManiac
//
//  Created by Dmitry Matyushkin on 28/05/2017.
//  Copyright © 2017 Dmitry Matyushkin. All rights reserved.
//

import UIKit
import CoreStore
import Combine
import CommonError

class AddShoppingItemViewController: ShoppingManiacViewController {

    @IBOutlet private weak var nameEditField: AutocompleteTextField!
    @IBOutlet private weak var storeEditField: AutocompleteTextField!
    @IBOutlet private weak var amountEditField: RoundRectTextField!
    @IBOutlet private weak var priceEditField: RoundRectTextField!
    @IBOutlet private weak var starButton1: UIButton!
    @IBOutlet private weak var starButton2: UIButton!
    @IBOutlet private weak var starButton3: UIButton!
    @IBOutlet private weak var starButton4: UIButton!
    @IBOutlet private weak var starButton5: UIButton!
    @IBOutlet private weak var weightSwitch: UISwitch!
    @IBOutlet private weak var importantItemSwitch: UISwitch!
    
    let model = AddShoppingListItemModel()

    override func viewDidLoad() {
        super.viewDidLoad()
		self.nameEditField.bind(to: model.itemName, store: &model.cancellables)
		self.storeEditField.bind(to: model.storeName, store: &model.cancellables)
		self.amountEditField.bind(to: model.amountText, store: &model.cancellables)
		self.priceEditField.bind(to: model.priceText, store: &model.cancellables)
		self.weightSwitch.bind(to: self.model.isWeight, store: &model.cancellables)
		self.starButton1.tagRatingBinding(variable: self.model.rating, store: &model.cancellables)
        self.starButton2.tagRatingBinding(variable: self.model.rating, store: &model.cancellables)
        self.starButton3.tagRatingBinding(variable: self.model.rating, store: &model.cancellables)
        self.starButton4.tagRatingBinding(variable: self.model.rating, store: &model.cancellables)
        self.starButton5.tagRatingBinding(variable: self.model.rating, store: &model.cancellables)
        self.importantItemSwitch.bind(to: self.model.importantItem, store: &model.cancellables)
        self.nameEditField.autocompleteStrings = self.model.listAllGoods()
        self.storeEditField.autocompleteStrings = self.model.listAllStores()
        
        self.nameEditField.becomeFirstResponder()
        self.model.applyData()
    }

	@IBAction private func saveAction(sender: UIButton) {
		guard let value = self.model.itemName.value, value.count > 0 else {
			CommonError(description: "Item name should not be empty").showError(title: "Unable to create item")
			return
		}
		self.model.persistDataAsync().observeOnMain().sink(receiveCompletion: {completion in
			switch completion {
			case .finished:
				break
			case .failure(let error):
				error.showError(title: "Unable to create item")
			}
		}, receiveValue: {[weak self] in
			self?.performSegue(withIdentifier: "addShoppingItemSaveSegue", sender: nil)
		}).store(in: &self.model.cancellables)
	}
}
