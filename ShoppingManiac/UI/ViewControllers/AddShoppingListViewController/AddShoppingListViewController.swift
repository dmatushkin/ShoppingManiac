//
//  AddShoppingListViewController.swift
//  ShoppingManiac
//
//  Created by Dmitry Matyushkin on 21/05/2017.
//  Copyright © 2017 Dmitry Matyushkin. All rights reserved.
//

import UIKit
import CoreStore
import RxSwift
import RxCocoa

class AddShoppingListViewController: ShoppingManiacViewController {

    private let disposeBag = DisposeBag()
    private let model = AddShoppingListModel()
    @IBOutlet weak var shoppingNameEditField: UITextField!

    override func viewDidLoad() {
        super.viewDidLoad()
        self.shoppingNameEditField.rx.text.orEmpty.bind(to: self.model.listTitle).disposed(by: self.disposeBag)
        self.shoppingNameEditField.becomeFirstResponder()
    }

    // MARK: - Navigation

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "addListSaveSegue", let list = self.model.createItem() {
            (segue.destination as? ShoppingListViewController)?.model.shoppingList = list
        }
    }
}
