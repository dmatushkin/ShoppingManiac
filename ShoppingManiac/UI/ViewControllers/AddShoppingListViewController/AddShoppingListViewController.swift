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
    @IBOutlet private weak var shoppingNameEditField: UITextField!
    var listsViewController: ShoppingListsListViewController?

    override func viewDidLoad() {
        super.viewDidLoad()
        self.shoppingNameEditField.rx.text.orEmpty.bind(to: self.model.listTitle).disposed(by: self.disposeBag)
        self.shoppingNameEditField.becomeFirstResponder()
    }

    @IBAction private func addAction(_ sender: Any) {
		guard let presenter = self.listsViewController else { return }
		self.model.createItemAsync().observeOnMain().subscribe(onNext: {list in
			self.dismiss(animated: true, completion: {
                presenter.showList(list: list, isNew: true)
            })
		}, onError: {error in
			error.showError(title: "Unable to create shopping list")
		}).disposed(by: self.disposeBag)
    }
    
    @IBAction private func cancelAction(_ sender: Any) {
        self.dismiss(animated: true, completion: nil)
    }
}
