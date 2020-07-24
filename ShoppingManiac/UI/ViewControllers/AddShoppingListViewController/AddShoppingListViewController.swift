//
//  AddShoppingListViewController.swift
//  ShoppingManiac
//
//  Created by Dmitry Matyushkin on 21/05/2017.
//  Copyright © 2017 Dmitry Matyushkin. All rights reserved.
//

import UIKit
import CoreStore
import Combine

class AddShoppingListViewController: ShoppingManiacViewController {

    private var cancellables = Set<AnyCancellable>()
    private let model = AddShoppingListModel()
    @IBOutlet private weak var shoppingNameEditField: UITextField!
    var listsViewController: ShoppingListsListViewController?

    override func viewDidLoad() {
        super.viewDidLoad()
		self.shoppingNameEditField.bind(to: self.model.listTitle, store: &cancellables)
        self.shoppingNameEditField.becomeFirstResponder()
    }

    @IBAction private func addAction(_ sender: Any) {
		guard let presenter = self.listsViewController else { return }
		self.model.createItemAsync().observeOnMain().sink(receiveCompletion: { completion in
			switch completion {
			case .finished:
				break
			case .failure(let error):
				error.showError(title: "Unable to create shopping list")
			}
		}, receiveValue: {[weak self] list in
			self?.dismiss(animated: true, completion: {
                presenter.showList(list: list, isNew: true)
            })
		}).store(in: &cancellables)
    }
    
    @IBAction private func cancelAction(_ sender: Any) {
        self.dismiss(animated: true, completion: nil)
    }
}
