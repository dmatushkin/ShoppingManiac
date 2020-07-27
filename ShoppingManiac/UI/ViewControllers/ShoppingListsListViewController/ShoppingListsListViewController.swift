//
//  ShoppingListsListViewController.swift
//  ShoppingManiac
//
//  Created by Dmitry Matyushkin on 21/05/2017.
//  Copyright © 2017 Dmitry Matyushkin. All rights reserved.
//

import UIKit
import CoreStore

class ShoppingListsListViewController: ShoppingManiacViewController, UITableViewDelegate {

    @IBOutlet private weak var tableView: UITableView!
    
    private let model = ShoppingListsListModel()

    override func viewDidLoad() {
        super.viewDidLoad()
        self.tableView.contentInsetAdjustmentBehavior = .never
		self.model.setupTable(tableView: tableView)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.tableView.reloadData()
    }

	func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
		let disableAction = UIContextualAction(style: .destructive, title: "Delete") {[weak self] (_, _, actionPerformed) in
			tableView.isEditing = false
			if let shoppingList = self?.model.getItem(forIndex: indexPath) {
                let alertController = UIAlertController(title: "Delete list", message: "Are you sure you want to delete list \(shoppingList.title)?", confirmActionTitle: "Delete") {[weak self] in
                    self?.model.deleteItem(shoppingList: shoppingList)
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
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if let item = self.model.getItem(forIndex: indexPath) {
			self.model.selectedRow = indexPath.row
            self.showList(list: item)
        }
    }
    
    func showList(list: ShoppingList, isNew: Bool = false) {
        if isNew {
			self.model.selectedRow = 0
        }
        self.performSegue(withIdentifier: "shoppingListSegue", sender: list)
    }
        
    // MARK: - Navigation

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "shoppingListSegue", let controller = (segue.destination as? UINavigationController)?.viewControllers.first as? ShoppingListViewController, let item = sender as? ShoppingList {
            controller.model.shoppingList = item
            self.tableView.reloadData()
        } else if segue.identifier == "addShoppingListSegue", let controller = segue.destination as? AddShoppingListViewController {
            controller.listsViewController = self
        }
    }

    @IBAction private func shoppingListsList(unwindSegue: UIStoryboardSegue) {
    }
}
