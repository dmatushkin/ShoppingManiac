//
//  AddShoppingItemViewController.swift
//  ShoppingManiac
//
//  Created by Dmitry Matyushkin on 28/05/2017.
//  Copyright © 2017 Dmitry Matyushkin. All rights reserved.
//

import UIKit
import CoreStore

class AddShoppingItemViewController: UIViewController {

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
    
    var rating: Int = 0 {
        didSet {
            let stars = [self.starButton1, self.starButton2, self.starButton3, self.starButton4, self.starButton5]
            for star in stars {
                star?.isSelected = (star?.tag ?? 0) <= rating
            }
        }
    }
    
    var shoppingListItem: ShoppingListItem?
    var shoppingList: ShoppingList!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.nameEditField.becomeFirstResponder()
        self.nameEditField.text = self.shoppingListItem?.good?.name
        self.nameEditField.autocompleteStrings = CoreStore.fetchAll(From<Good>(), OrderBy(.ascending("name")))?.map({ $0.name }).filter({ $0 != nil && $0!.characters.count > 0 }).map({ $0! }) ?? []
        self.storeEditField.autocompleteStrings = CoreStore.fetchAll(From<Store>(), OrderBy(.ascending("name")))?.map({ $0.name }).filter({ $0 != nil && $0!.characters.count > 0 }).map({ $0! }) ?? []
        self.storeEditField.text = self.shoppingListItem?.store?.name
        if let price = self.shoppingListItem?.price, price > 0 {
            self.priceEditField.text = "\(price)"
        }
        if let amount = self.shoppingListItem?.quantityText {
            self.amountEditField.text = amount
        }
        self.weightSwitch.isOn = (self.shoppingListItem?.isWeight == true)
        self.rating = Int(self.shoppingListItem?.good?.personalRating ?? 0)
    }
        
    private func updateItem(withName name: String) {
        try? CoreStore.perform(synchronous: { transaction in
            let item = self.shoppingListItem == nil ? transaction.create(Into<ShoppingListItem>()) : transaction.edit(self.shoppingListItem)
            if let good = transaction.fetchOne(From<Good>(), Where("name == %@", name)) {
                item?.good = good
            } else {
                let good = transaction.create(Into<Good>())
                good.name = name
                item?.good = good
            }
            item?.isWeight = self.weightSwitch.isOn
            item?.good?.personalRating = Int16(self.rating)
            if let storeName = self.storeEditField.text, storeName.characters.count > 0 {
                if let store = transaction.fetchOne(From<Store>(), Where("name == %@", storeName)) {
                    item?.store = store
                } else {
                    let store = transaction.create(Into<Store>())
                    store.name = storeName
                    item?.store = store
                }
            } else {
                item?.store = nil
            }
            if let amount = self.amountEditField.text?.replacingOccurrences(of: ",", with: "."), amount.characters.count > 0, let value = Float(amount) {
                item?.quantity = value
            } else {
                item?.quantity = 1
            }
            if let price = self.priceEditField.text?.replacingOccurrences(of: ",", with: "."), price.characters.count > 0, let value = Float(price) {
                item?.price = value
            } else {
                item?.price = 0
            }
            item?.list = transaction.edit(self.shoppingList)
        })
    }

    // MARK: - Navigation

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
    }
    
    override func shouldPerformSegue(withIdentifier identifier: String, sender: Any?) -> Bool {
        if identifier == "addShoppingItemSaveSegue" {
            if let name = self.nameEditField.text, name.characters.count > 0 {
                self.updateItem(withName: name)
                return true
            } else {
                return false
            }
        } else {
            return true
        }
    }
    
    @IBAction func starSelectedAction(button: UIButton) {
        self.rating = button.tag
    }
}
