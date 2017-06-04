//
//  AddGoodViewController.swift
//  ShoppingManiac
//
//  Created by Dmitry Matyushkin on 21/05/2017.
//  Copyright © 2017 Dmitry Matyushkin. All rights reserved.
//

import UIKit
import CoreStore

class AddGoodViewController: UIViewController, UITableViewDataSource, UITableViewDelegate {

    @IBOutlet weak var goodNameEditField: UITextField!
    @IBOutlet weak var goodCategoryEditField: UITextField!
    @IBOutlet weak var ratingStar1Button: UIButton!
    @IBOutlet weak var ratingStar2Button: UIButton!
    @IBOutlet weak var ratingStar3Button: UIButton!
    @IBOutlet weak var ratingStar4Button: UIButton!
    @IBOutlet weak var ratingStar5Button: UIButton!
    @IBOutlet weak var categoriesTable: UITableView!
    @IBOutlet weak var cancelCategorySelectionButton: UIButton!
    @IBOutlet var categorySelectionPanel: UIView!
    private var stars: [UIButton] = []
    
    var good: Good?
    private var rating: Int = 0 {
        didSet {
            for star in self.stars {
                star.isSelected = (star.tag <= rating)
            }
        }
    }
    private var category: Category? = nil {
        didSet {
            self.goodCategoryEditField.text = category?.name
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.stars = [self.ratingStar1Button, self.ratingStar2Button, self.ratingStar3Button, self.ratingStar4Button, self.ratingStar5Button]
        self.goodNameEditField.text = good?.name
        self.category = good?.category
        self.rating = Int(good?.personalRating ?? 0)
        self.goodNameEditField.becomeFirstResponder()
        self.goodCategoryEditField.inputView = self.categorySelectionPanel
    }
    
    private func createItem(withName name: String) {
        CoreStore.beginSynchronous { (transaction) in
            let item = transaction.create(Into<Good>())
            item.name = name
            item.category = transaction.edit(self.category)
            item.personalRating = Int16(self.rating)
            let _ = transaction.commit()
        }
    }
    
    private func updateItem(item: Good, withName name: String) {
        CoreStore.beginSynchronous { (transaction) in
            let item = transaction.edit(item)
            item?.name = name
            item?.category = transaction.edit(self.category)
            item?.personalRating = Int16(self.rating)
            let _ = transaction.commit()
        }
    }
    
    @IBAction func starSelectedAction(button: UIButton) {
        self.rating = button.tag
    }
    
    @IBAction func editCategoryAction(_ sender: Any) {
        self.categoriesTable.isHidden = (CoreStore.fetchCount(From<Category>(), []) ?? 0) == 0
        self.categoriesTable.reloadData()
    }
    
    @IBAction func cancelCategorySelectionAction(_ sender: Any) {
        self.goodCategoryEditField.endEditing(true)
    }
    
    public func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return CoreStore.fetchCount(From<Category>(), []) ?? 0
    }
    
    public func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if let cell: CategorySelectionTableViewCell = tableView.dequeueCell(indexPath: indexPath) {
            cell.setup(withCategory: self.getItem(forIndex: indexPath))
            return cell
        } else {
            return UITableViewCell()
        }
    }
    
    func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        return CGFloat.leastNormalMagnitude
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        self.category = self.getItem(forIndex: indexPath)
        self.goodCategoryEditField.endEditing(true)
    }
    
    private func getItem(forIndex: IndexPath) -> Category? {
        return CoreStore.fetchOne(From<Category>(), OrderBy(.ascending("name")), Tweak({ fetchRequest in
            fetchRequest.fetchOffset = forIndex.row
        }))
    }

    // MARK: - Navigation

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
    }
    
    override func shouldPerformSegue(withIdentifier identifier: String, sender: Any?) -> Bool {
        if identifier == "addGoodSaveSegue" {
            if let name = self.goodNameEditField.text, name.characters.count > 0 {
                if let item = self.good {
                    self.updateItem(item: item, withName: name)
                } else {
                    self.createItem(withName: name)
                }
                return true
            } else {
                return false
            }
        } else {
            return true
        }
    }
}
