//
//  AddGoodViewController.swift
//  ShoppingManiac
//
//  Created by Dmitry Matyushkin on 21/05/2017.
//  Copyright © 2017 Dmitry Matyushkin. All rights reserved.
//

import UIKit
import CoreStore
import RxSwift
import RxCocoa

class AddGoodViewController: ShoppingManiacViewController, UITableViewDataSource, UITableViewDelegate {

    @IBOutlet private weak var goodNameEditField: UITextField!
    @IBOutlet private weak var goodCategoryEditField: UITextField!
    @IBOutlet private weak var ratingStar1Button: UIButton!
    @IBOutlet private weak var ratingStar2Button: UIButton!
    @IBOutlet private weak var ratingStar3Button: UIButton!
    @IBOutlet private weak var ratingStar4Button: UIButton!
    @IBOutlet private weak var ratingStar5Button: UIButton!
    @IBOutlet private weak var categoriesTable: UITableView!
    @IBOutlet private weak var cancelCategorySelectionButton: UIButton!
    @IBOutlet var categorySelectionPanel: UIView!
    private var stars: [UIButton] = []
    
    let model = AddGoodModel()
	private let disposeBag = DisposeBag()

    override func viewDidLoad() {
        super.viewDidLoad()
        self.stars = [self.ratingStar1Button, self.ratingStar2Button, self.ratingStar3Button, self.ratingStar4Button, self.ratingStar5Button]
        (self.goodNameEditField.rx.text.orEmpty <-> self.model.goodName).disposed(by: self.model.disposeBag)
        self.model.goodCategory.asObservable().bind(to: self.goodCategoryEditField.rx.text).disposed(by: self.model.disposeBag)
        self.ratingStar1Button.tagRatingBinding(variable: self.model.rating).disposed(by: self.model.disposeBag)
        self.ratingStar2Button.tagRatingBinding(variable: self.model.rating).disposed(by: self.model.disposeBag)
        self.ratingStar3Button.tagRatingBinding(variable: self.model.rating).disposed(by: self.model.disposeBag)
        self.ratingStar4Button.tagRatingBinding(variable: self.model.rating).disposed(by: self.model.disposeBag)
        self.ratingStar5Button.tagRatingBinding(variable: self.model.rating).disposed(by: self.model.disposeBag)
        self.goodNameEditField.becomeFirstResponder()
        self.goodCategoryEditField.inputView = self.categorySelectionPanel
        self.model.applyData()
    }

    @IBAction private func editCategoryAction(_ sender: Any) {
        self.categoriesTable.isHidden = self.model.categoriesCount() == 0
        self.categoriesTable.reloadData()
    }

    @IBAction private func cancelCategorySelectionAction(_ sender: Any) {
        self.goodCategoryEditField.endEditing(true)
    }

	@IBAction private func saveAction() {
		guard self.model.goodName.value.count > 0 else {
			CommonError(description: "Good name should not be empty").showError(title: "Unable to create good")
			return
		}
		self.model.persistChangesAsync().observeOnMain().subscribe(onNext: {[weak self] in
			self?.performSegue(withIdentifier: "addGoodSaveSegue", sender: nil)
		}, onError: {error in
			error.showError(title: "Unable to create good")
		}).disposed(by: self.disposeBag)
	}

    public func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return self.model.categoriesCount()
    }

    public func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if let cell: CategorySelectionTableViewCell = tableView.dequeueCell(indexPath: indexPath) {
            cell.setup(withCategory: self.model.getCategoryItem(forIndex: indexPath))
            return cell
        } else {
            fatalError()
        }
    }

    func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        return CGFloat.leastNormalMagnitude
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        self.model.category = self.model.getCategoryItem(forIndex: indexPath)
        self.goodCategoryEditField.endEditing(true)
    }
    
    // MARK: - Navigation

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
    }
}
