//
//  AddGoodViewController.swift
//  ShoppingManiac
//
//  Created by Dmitry Matyushkin on 21/05/2017.
//  Copyright © 2017 Dmitry Matyushkin. All rights reserved.
//

import UIKit
import CoreStore
import Combine

class AddGoodViewController: ShoppingManiacViewController, UITableViewDelegate {

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
	private var cancellables = Set<AnyCancellable>()

    override func viewDidLoad() {
        super.viewDidLoad()
        self.stars = [self.ratingStar1Button, self.ratingStar2Button, self.ratingStar3Button, self.ratingStar4Button, self.ratingStar5Button]
		self.goodNameEditField.bind(to: self.model.goodName, store: &cancellables)
		self.goodCategoryEditField.bind(to: self.model.goodCategory, store: &cancellables)
        self.ratingStar1Button.tagRatingBinding(variable: self.model.rating, store: &cancellables)
        self.ratingStar2Button.tagRatingBinding(variable: self.model.rating, store: &cancellables)
        self.ratingStar3Button.tagRatingBinding(variable: self.model.rating, store: &cancellables)
        self.ratingStar4Button.tagRatingBinding(variable: self.model.rating, store: &cancellables)
        self.ratingStar5Button.tagRatingBinding(variable: self.model.rating, store: &cancellables)
        self.goodNameEditField.becomeFirstResponder()
        self.goodCategoryEditField.inputView = self.categorySelectionPanel
		self.model.setupTable(tableView: categoriesTable)
        self.model.applyData()
    }

    @IBAction private func editCategoryAction(_ sender: Any) {
        self.categoriesTable.isHidden = self.model.categoriesCount() == 0
        self.categoriesTable.reloadData()
    }

    @IBAction private func cancelCategorySelectionAction(_ sender: Any) {
		self.model.clearCategory()
        self.goodCategoryEditField.endEditing(true)
    }

	@IBAction private func saveAction() {
		guard let value = self.model.goodName.value, value.count > 0 else {
			CommonError(description: "Good name should not be empty").showError(title: "Unable to create good")
			return
		}
		self.model.persistChangesAsync().observeOnMain().sink(receiveCompletion: { completion in
			switch completion {
			case .finished:
				break
			case .failure(let error):
				error.showError(title: "Unable to create good")
			}
		}, receiveValue: {[weak self] in
			self?.performSegue(withIdentifier: "addGoodSaveSegue", sender: nil)
		}).store(in: &cancellables)
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
