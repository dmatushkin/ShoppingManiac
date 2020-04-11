//
//  AddStoreViewController.swift
//  ShoppingManiac
//
//  Created by Dmitry Matyushkin on 21/05/2017.
//  Copyright © 2017 Dmitry Matyushkin. All rights reserved.
//

import UIKit
import CoreStore
import RxSwift

class AddStoreViewController: ShoppingManiacViewController {

    @IBOutlet private weak var storeNameEditField: UITextField!

    let model = AddStoreModel()
	private let disposeBag = DisposeBag()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        (self.storeNameEditField.rx.text.orEmpty <-> self.model.storeName).disposed(by: self.model.disposeBag)
        self.storeNameEditField.becomeFirstResponder()
        self.model.applyData()
    }

	@IBAction private func saveAction() {
		guard self.model.storeName.value.count > 0 else {
			CommonError(description: "Store name should not be empty").showError(title: "Unable to create store")
			return
		}
		self.model.persistDataAsync().observeOnMain().subscribe(onNext: {[weak self] in
			self?.performSegue(withIdentifier: "addStoreSaveSegue", sender: nil)
			}, onError: {error in
				error.showError(title: "Unable to create store")
		}).disposed(by: self.disposeBag)
	}
}
