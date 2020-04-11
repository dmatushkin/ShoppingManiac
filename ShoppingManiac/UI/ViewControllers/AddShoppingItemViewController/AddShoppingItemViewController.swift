//
//  AddShoppingItemViewController.swift
//  ShoppingManiac
//
//  Created by Dmitry Matyushkin on 28/05/2017.
//  Copyright © 2017 Dmitry Matyushkin. All rights reserved.
//

import UIKit
import CoreStore
import RxSwift
import RxCocoa

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
    @IBOutlet private weak var crossListItemSwitch: UISwitch!
    
    let model = AddShoppingListItemModel()
	private let disposeBag = DisposeBag()

    override func viewDidLoad() {
        super.viewDidLoad()
        (self.nameEditField.rx.text.orEmpty <-> self.model.itemName).disposed(by: self.model.disposeBag)
        (self.storeEditField.rx.text.orEmpty <-> self.model.storeName).disposed(by: self.model.disposeBag)
        (self.amountEditField.rx.text.orEmpty <-> self.model.amountText).disposed(by: self.model.disposeBag)
        (self.priceEditField.rx.text.orEmpty <-> self.model.priceText).disposed(by: self.model.disposeBag)
        (self.weightSwitch.rx.isOn <-> self.model.isWeight).disposed(by: self.model.disposeBag)
        self.starButton1.tagRatingBinding(variable: self.model.rating).disposed(by: self.model.disposeBag)
        self.starButton2.tagRatingBinding(variable: self.model.rating).disposed(by: self.model.disposeBag)
        self.starButton3.tagRatingBinding(variable: self.model.rating).disposed(by: self.model.disposeBag)
        self.starButton4.tagRatingBinding(variable: self.model.rating).disposed(by: self.model.disposeBag)
        self.starButton5.tagRatingBinding(variable: self.model.rating).disposed(by: self.model.disposeBag)
        (self.crossListItemSwitch.rx.isOn <-> self.model.crossListItem).disposed(by: self.model.disposeBag)
        self.nameEditField.autocompleteStrings = self.model.listAllGoods()
        self.storeEditField.autocompleteStrings = self.model.listAllStores()
        
        self.nameEditField.becomeFirstResponder()
        self.model.applyData()
    }

	@IBAction private func saveAction(sender: UIButton) {
		guard self.model.itemName.value.count > 0 else {
			CommonError(description: "Item name should not be empty").showError(title: "Unable to create item")
			return
		}
		self.model.persistDataAsync().observeOnMain().subscribe(onNext: {[weak self] in
			self?.performSegue(withIdentifier: "addShoppingItemSaveSegue", sender: nil)
		}, onError: { error in
			error.showError(title: "Unable to create item")
		}).disposed(by: self.disposeBag)
	}
}
