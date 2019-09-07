//
//  ShoppingListsListViewController.swift
//  ShoppingManiac
//
//  Created by Dmitry Matyushkin on 21/05/2017.
//  Copyright © 2017 Dmitry Matyushkin. All rights reserved.
//

import UIKit
import RxSwift

class ShoppingListsListViewController: ShoppingManiacViewController, UITableViewDataSource, UITableViewDelegate {

    @IBOutlet private weak var tableView: UITableView!
    
    private let model = ShoppingListsListModel()

    override func viewDidLoad() {
        super.viewDidLoad()
        self.automaticallyAdjustsScrollViewInsets = false
        self.model.onUpdate = {[weak self] in
            self?.tableView.reloadData()
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.tableView.reloadData()
    }

    public func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return model.itemsCount()
    }

    public func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if let item = self.model.getItem(forIndex: indexPath), let cell: ShoppingListsListTableViewCell = tableView.dequeueCell(indexPath: indexPath) {
            cell.setup(withList: item)
            return cell
        } else {
            fatalError()
        }
    }

    func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        return true
    }

    func tableView(_ tableView: UITableView, editActionsForRowAt indexPath: IndexPath) -> [UITableViewRowAction]? {
        let disableAction = UITableViewRowAction(style: UITableViewRowAction.Style.default, title: "Delete") { [weak self] _, indexPath in
            tableView.isEditing = false
            if let shoppingList = self?.model.getItem(forIndex: indexPath) {
                let alertController = UIAlertController(title: "Delete list", message: "Are you sure you want to delete list \(shoppingList.title)?", confirmActionTitle: "Delete") {[weak self] in
                    self?.model.deleteItem(shoppingList: shoppingList)
                }
                self?.present(alertController, animated: true, completion: nil)
            }
        }
        disableAction.backgroundColor = UIColor.red
        return [disableAction]
    }

    func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {

    }

    func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        return CGFloat.leastNormalMagnitude
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if let item = self.model.getItem(forIndex: indexPath) {
            self.showList(list: item)
        }
    }
    
    func showList(list: ShoppingList) {
        self.performSegue(withIdentifier: "shoppingListSegue", sender: list)
    }

    // MARK: - Navigation

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "shoppingListSegue", let controller = (segue.destination as? UINavigationController)?.viewControllers.first as? ShoppingListViewController, let item = sender as? ShoppingList {
            controller.model.shoppingList = item
        } else if segue.identifier == "addShoppingListSegue", let controller = segue.destination as? AddShoppingListViewController {
            controller.listsViewController = self
        }
    }

    @IBAction private func shoppingListsList(unwindSegue: UIStoryboardSegue) {
    }
}
