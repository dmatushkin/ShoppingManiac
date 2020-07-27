//
//  CategoriesListViewController.swift
//  ShoppingManiac
//
//  Created by Dmitry Matyushkin on 21/05/2017.
//  Copyright © 2017 Dmitry Matyushkin. All rights reserved.
//

import UIKit
import CoreStore

class CategoriesListViewController: ShoppingManiacViewController, UITableViewDelegate {

    @IBOutlet private weak var tableView: UITableView!

    private let model = CategoriesListModel()

    override func viewDidLoad() {
        super.viewDidLoad()
		self.model.setupTable(tableView: tableView)
        self.tableView.contentInsetAdjustmentBehavior = .never
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.tableView.reloadData()
    }

	func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
		let disableAction = UIContextualAction(style: .destructive, title: "Delete") {[weak self] (_, _, actionPerformed) in
			tableView.isEditing = false
			if let item = self?.model.getItem(forIndex: indexPath) {
                let alertController = UIAlertController(title: "Delete category", message: "Are you sure you want to delete \(item.name ?? "category")?", confirmActionTitle: "Delete") {[weak self] in
                    self?.model.deleteItem(item: item)
                }
                self?.present(alertController, animated: true, completion: nil)
            }
			actionPerformed(true)
		}
		return UISwipeActionsConfiguration(actions: [disableAction])
	}

    func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        return CGFloat.leastNormalMagnitude
    }

    // MARK: - Navigation

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "editCateogrySegue", let controller = segue.destination as? AddCategoryViewController, let path = self.tableView.indexPathForSelectedRow, let item = self.model.getItem(forIndex: path) {
            controller.model.category = item
        }
    }

    @IBAction private func categoriesList(unwindSegue: UIStoryboardSegue) {
        if unwindSegue.identifier == "addCategorySaveSegue" {
            self.tableView.reloadData()
        }
    }
}
