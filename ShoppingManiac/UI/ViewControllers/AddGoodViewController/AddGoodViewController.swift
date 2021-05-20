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
import CommonError

class AddGoodViewController: ShoppingManiacViewController {

    @IBOutlet private weak var goodNameEditField: UITextField!
    @IBOutlet private weak var goodCategoryEditField: AutocompleteTextField!
    @IBOutlet private weak var ratingStar1Button: UIButton!
    @IBOutlet private weak var ratingStar2Button: UIButton!
    @IBOutlet private weak var ratingStar3Button: UIButton!
    @IBOutlet private weak var ratingStar4Button: UIButton!
    @IBOutlet private weak var ratingStar5Button: UIButton!
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
        self.goodCategoryEditField.autocompleteStrings = self.model.listAllCategories()
        self.model.applyData()
    }

	@IBAction private func saveAction() {
        guard let value = self.model.goodName.value, !value.isEmpty else {
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
    
    // MARK: - Navigation

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
    }
}
