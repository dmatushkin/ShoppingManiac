//
//  AddCategoryViewController.swift
//  ShoppingManiac
//
//  Created by Dmitry Matyushkin on 21/05/2017.
//  Copyright © 2017 Dmitry Matyushkin. All rights reserved.
//

import UIKit
import CoreStore
import RxSwift

class AddCategoryViewController: ShoppingManiacViewController {

    @IBOutlet private weak var categoryNameEditField: UITextField!
    
    let model = AddCategoryModel()
	private let disposeBag = DisposeBag()

    override func viewDidLoad() {
        super.viewDidLoad()
        (self.categoryNameEditField.rx.text.orEmpty <-> self.model.categoryName).disposed(by: self.model.disposeBag)
        self.categoryNameEditField.becomeFirstResponder()
        self.model.applyData()
    }

	@IBAction private func saveAction() {
		guard self.model.categoryName.value.count > 0 else {
			CommonError(description: "Category name should not be empty").showError(title: "Unable to create category")
			return
		}
		self.model.persistDataAsync().observeOnMain().subscribe(onNext: {[weak self] in
			self?.performSegue(withIdentifier: "addCategorySaveSegue", sender: nil)
			}, onError: {error in
				error.showError(title: "Unable to create category")
		}).disposed(by: self.disposeBag)
	}
}
