//
//  ShoppingListViewController.swift
//  ShoppingManiac
//
//  Created by Dmitry Matyushkin on 21/05/2017.
//  Copyright © 2017 Dmitry Matyushkin. All rights reserved.
//

import UIKit
import CoreStore

class GroupItem {
    let objectId: NSManagedObjectID
    let itemName: String
    let itemGroupName: String?
    let itemQuantityString: String
    var purchased: Bool = false
    
    init(shoppingListItem: ShoppingListItem) {
        self.objectId = shoppingListItem.objectID
        self.itemName = shoppingListItem.good?.name ?? "No name"
        self.itemGroupName = shoppingListItem.store?.name
        self.itemQuantityString = shoppingListItem.quantityText
        self.purchased = shoppingListItem.purchased
    }
}

class ShoppingGroup {
    let groupName: String?
    let items: [GroupItem]
    
    init(name: String?, items:[GroupItem]) {
        self.groupName = name
        self.items = items
    }
}

class ShoppingListViewController: UIViewController, UITableViewDataSource, UITableViewDelegate {

    @IBOutlet weak var tableView: UITableView!
    
    var shoppingList: ShoppingList!
    
    var shoppingGroups:[ShoppingGroup] = []
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.automaticallyAdjustsScrollViewInsets = false
    }
    
    func reloadData() {
        
    }
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return self.shoppingGroups.count
    }
    
    public func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return self.shoppingGroups[section].items.count
    }
    
    public func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if let cell: ShoppingListTableViewCell = tableView.dequeueCell(indexPath: indexPath) {
            cell.setup(withItem: self.shoppingGroups[indexPath.section].items[indexPath.row])
            return cell
        } else {
            return UITableViewCell()
        }
    }
    
    func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        return true
    }
    
    func tableView(_ tableView: UITableView, editActionsForRowAt indexPath: IndexPath) -> [UITableViewRowAction]? {
        let editAction = UITableViewRowAction(style: UITableViewRowActionStyle.default, title: "Edit") { [unowned self] action, indexPath in
            tableView.isEditing = false
            /*if let item = self.getItem(forIndex: indexPath) {
                let alertController = UIAlertController(title: "Delete store", message: "Are you sure you want to delete \(item.name ?? "store")?", confirmActionTitle: "Delete") {
                    CoreStore.beginAsynchronous { (transaction) in
                        transaction.delete(item)
                        transaction.commit()
                        DispatchQueue.main.async {
                            self.tableView.reloadData()
                        }
                    }
                }
                self.present(alertController, animated: true, completion: nil)
            }*/
        }
        editAction.backgroundColor = UIColor.gray
        
        return [editAction]
    }
    
    func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCellEditingStyle, forRowAt indexPath: IndexPath) {
        
    }
    
    func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        return CGFloat.leastNormalMagnitude
    }
    
    private func getItem(forIndex: IndexPath) -> ShoppingListItem? {
        return CoreStore.fetchOne(From<ShoppingListItem>(), OrderBy(.ascending("name")), Tweak({ fetchRequest in
            fetchRequest.fetchOffset = forIndex.row
        }))
    }
    
    // MARK: - Navigation
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
    }
    
    @IBAction func shoppingList(unwindSegue: UIStoryboardSegue) {
    }
}
