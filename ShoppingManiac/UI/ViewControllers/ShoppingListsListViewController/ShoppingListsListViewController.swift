//
//  ShoppingListsListViewController.swift
//  ShoppingManiac
//
//  Created by Dmitry Matyushkin on 21/05/2017.
//  Copyright © 2017 Dmitry Matyushkin. All rights reserved.
//

import UIKit
import CoreStore
import NoticeObserveKit

class ShoppingListsListViewController: ShoppingManiacViewController, UITableViewDataSource, UITableViewDelegate {

    @IBOutlet weak var tableView: UITableView!
    
    private let pool = NoticeObserverPool()

    override func viewDidLoad() {
        super.viewDidLoad()
        self.automaticallyAdjustsScrollViewInsets = false
        NewDataAvailable.observe {[weak self] _ in
            self?.tableView.reloadData()
        }.disposed(by: self.pool)
    }

    var listToShow: ShoppingList?

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.tableView.reloadData()
    }

    public func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return CoreStore.fetchCount(From<ShoppingList>().where(Where("isRemoved == false"))) ?? 0
    }

    public func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if let item = self.getItem(forIndex: indexPath), let cell: ShoppingListsListTableViewCell = tableView.dequeueCell(indexPath: indexPath) {
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
        let disableAction = UITableViewRowAction(style: UITableViewRowActionStyle.default, title: "Delete") { [unowned self] _, indexPath in
            tableView.isEditing = false
            if let shoppingList = self.getItem(forIndex: indexPath) {
                let alertController = UIAlertController(title: "Delete list", message: "Are you sure you want to delete list \(shoppingList.title)?", confirmActionTitle: "Delete") {
                    CoreStore.perform(asynchronous: { transaction in
                        let list = transaction.edit(shoppingList)
                        list?.isRemoved = true
                    }, completion: { _ in
                        CloudShare.updateList(list: shoppingList)
                        self.tableView.reloadData()
                    })
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
        return CoreStore.fetchOne(From<ShoppingList>().where(Where("isRemoved == false")).orderBy(.descending(\.date)).tweak({ fetchRequest in
            fetchRequest.fetchOffset = forIndex.row
            fetchRequest.fetchLimit = 1
        }))
    }

    // MARK: - Navigation

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "shoppingListSegue", let controller = segue.destination as? ShoppingListViewController {
            if let item = self.listToShow {
                controller.shoppingList = item
            } else if let path = self.tableView.indexPathForSelectedRow, let item = self.getItem(forIndex: path) {
                controller.shoppingList = item
            }
            self.listToShow = nil
        }
    }

    @IBAction func shoppingListsList(unwindSegue: UIStoryboardSegue) {
        if unwindSegue.identifier == "addListSaveSegue" {
            self.tableView.reloadData()
            //self.tableView.selectRow(at: IndexPath(row: 0, section: 0) , animated: true, scrollPosition: .top)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.performSegue(withIdentifier: "shoppingListSegue", sender: self)
            }
        }
    }
}
