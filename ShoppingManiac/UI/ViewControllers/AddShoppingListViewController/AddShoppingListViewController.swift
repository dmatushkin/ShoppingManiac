//
//  AddShoppingListViewController.swift
//  ShoppingManiac
//
//  Created by Dmitry Matyushkin on 21/05/2017.
//  Copyright © 2017 Dmitry Matyushkin. All rights reserved.
//

import UIKit
import RxSwift
import RxCocoa

class AddShoppingListViewController: ShoppingManiacViewController {

    private let disposeBag = DisposeBag()
    private let model = AddShoppingListModel()
    @IBOutlet private weak var shoppingNameEditField: UITextField!
    var listsViewController: UIViewController?

    override func viewDidLoad() {
        super.viewDidLoad()
        self.shoppingNameEditField.rx.text.orEmpty.bind(to: self.model.listTitle).disposed(by: self.disposeBag)
        self.shoppingNameEditField.becomeFirstResponder()
    }

    @IBAction func addAction(_ sender: Any) {
        if let list = self.model.createItem(), let presenter = self.listsViewController {
            self.dismiss(animated: true, completion: {
                presenter.performSegue(withIdentifier: "shoppingListSegue", sender: list)
            })
        }
    }
    // MARK: - Navigation

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "addListSaveSegue", let list = self.model.createItem() {
            (segue.destination as? ShoppingListViewController)?.model.shoppingList = list
        }
    }
}
