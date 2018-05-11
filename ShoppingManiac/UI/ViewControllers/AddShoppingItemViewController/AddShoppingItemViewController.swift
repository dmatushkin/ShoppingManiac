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

    @IBOutlet weak var nameEditField: AutocompleteTextField!
    @IBOutlet weak var storeEditField: AutocompleteTextField!
    @IBOutlet weak var amountEditField: RoundRectTextField!
    @IBOutlet weak var priceEditField: RoundRectTextField!
    @IBOutlet weak var starButton1: UIButton!
    @IBOutlet weak var starButton2: UIButton!
    @IBOutlet weak var starButton3: UIButton!
    @IBOutlet weak var starButton4: UIButton!
    @IBOutlet weak var starButton5: UIButton!
    @IBOutlet weak var weightSwitch: UISwitch!
    
    let model = AddShoppingListItemModel()

    override func viewDidLoad() {
        super.viewDidLoad()
        (self.nameEditField.rx.text.orEmpty <-> self.model.itemName).disposed(by: self.model.disposeBag)
        (self.storeEditField.rx.text.orEmpty <-> self.model.storeName).disposed(by: self.model.disposeBag)
        (self.amountEditField.rx.text.orEmpty <-> self.model.amountText).disposed(by: self.model.disposeBag)
        (self.priceEditField.rx.text.orEmpty <-> self.model.priceText).disposed(by: self.model.disposeBag)
        (self.weightSwitch.rx.isOn <-> self.model.isWeight).disposed(by: self.model.disposeBag)
        self.nameEditField.autocompleteStrings = self.model.listAllGoods()
        self.storeEditField.autocompleteStrings = self.model.listAllStores()
        self.model.rating.asObservable().subscribe(onNext: {[weak self] rating in
            guard let `self` = self else { return }
            let stars = [self.starButton1, self.starButton2, self.starButton3, self.starButton4, self.starButton5]
            for star in stars {
                star?.isSelected = (star?.tag ?? 0) <= rating
            }
        }).disposed(by: self.model.disposeBag)
        
        self.nameEditField.becomeFirstResponder()
        self.model.applyData()
    }

    // MARK: - Navigation

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
    }

    override func shouldPerformSegue(withIdentifier identifier: String, sender: Any?) -> Bool {
        if identifier == "addShoppingItemSaveSegue" {
            if self.model.itemName.value.count > 0 {
                self.model.persistData()
                return true
            } else {
                return false
            }
        } else {
            return true
        }
    }

    @IBAction func starSelectedAction(button: UIButton) {
        self.model.rating.value = button.tag
    }
}
