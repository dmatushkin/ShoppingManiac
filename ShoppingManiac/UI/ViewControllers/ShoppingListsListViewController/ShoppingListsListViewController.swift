//
//  ShoppingListsListViewController.swift
//  ShoppingManiac
//
//  Created by Dmitry Matyushkin on 21/05/2017.
//  Copyright © 2017 Dmitry Matyushkin. All rights reserved.
//

import UIKit
import CoreStore

class ShoppingListsListViewController: UIViewController, UITableViewDataSource, UITableViewDelegate {

    @IBOutlet weak var tableView: UITableView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.automaticallyAdjustsScrollViewInsets = false
    }
    
    public func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return CoreStore.fetchCount(From<ShoppingList>(), []) ?? 0
    }
    
    public func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if let item = self.getItem(forIndex: indexPath), let cell: ShoppingListsListTableViewCell = tableView.dequeueCell(indexPath: indexPath) {
            cell.setup(withList: item)
            return cell
        } else {
            return UITableViewCell()
        }
    }
    
    func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        return true
    }
    
    func tableView(_ tableView: UITableView, editActionsForRowAt indexPath: IndexPath) -> [UITableViewRowAction]? {
        let disableAction = UITableViewRowAction(style: UITableViewRowActionStyle.default, title: "Delete") { [unowned self] action, indexPath in
            tableView.isEditing = false
            if let shoppingList = self.getItem(forIndex: indexPath) {
                let alertController = UIAlertController(title: "Delete list", message: "Are you sure you want to delete list \(shoppingList.title)?", confirmActionTitle: "Delete") {
                    CoreStore.beginAsynchronous { (transaction) in
                        transaction.delete(shoppingList)
                        transaction.commit()
                        DispatchQueue.main.async {
                            self.tableView.reloadData()
                        }
                    }
                }
                self.present(alertController, animated: true, completion: nil)
            }
        }
        disableAction.backgroundColor = UIColor.red
        
        return [disableAction]
    }
    
    func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCellEditingStyle, forRowAt indexPath: IndexPath) {
        
    }
    
    func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        return CGFloat.leastNormalMagnitude
    }
    
    private func getItem(forIndex: IndexPath) -> ShoppingList? {
        return CoreStore.fetchOne(From<ShoppingList>(), OrderBy(.descending("date")), Tweak({ fetchRequest in
            fetchRequest.fetchOffset = forIndex.row
        }))
    }
    
    // MARK: - Navigation
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "shoppingListSegue", let controller = segue.destination as? ShoppingListViewController, let path = self.tableView.indexPathForSelectedRow, let item = self.getItem(forIndex: path) {
            controller.shoppingList = item
        }
    }
    
    @IBAction func shoppingListsList(unwindSegue: UIStoryboardSegue) {
        if unwindSegue.identifier == "addListSaveSegue" {
            self.tableView.reloadData()
        }
    }
}
