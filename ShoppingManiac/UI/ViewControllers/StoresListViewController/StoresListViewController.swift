//
//  StoresListViewController.swift
//  ShoppingManiac
//
//  Created by Dmitry Matyushkin on 21/05/2017.
//  Copyright © 2017 Dmitry Matyushkin. All rights reserved.
//

import UIKit
import CoreStore

class StoresListViewController: UIViewController, UITableViewDataSource, UITableViewDelegate {

    @IBOutlet weak var tableView: UITableView!

    override func viewDidLoad() {
        super.viewDidLoad()
        self.automaticallyAdjustsScrollViewInsets = false
    }

    public func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return CoreStore.fetchCount(From<Store>(), []) ?? 0
    }

    public func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if let item = self.getItem(forIndex: indexPath), let cell: StoresListTableViewCell = tableView.dequeueCell(indexPath: indexPath) {
            cell.setup(withStore: item)
            return cell
        } else {
            return UITableViewCell()
        }
    }

    func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        return true
    }

    func tableView(_ tableView: UITableView, editActionsForRowAt indexPath: IndexPath) -> [UITableViewRowAction]? {
        let disableAction = UITableViewRowAction(style: UITableViewRowActionStyle.default, title: "Delete") { [unowned self] _, indexPath in
            tableView.isEditing = false
            if let item = self.getItem(forIndex: indexPath) {
                let alertController = UIAlertController(title: "Delete store", message: "Are you sure you want to delete \(item.name ?? "store")?", confirmActionTitle: "Delete") {
                    CoreStore.perform(asynchronous: { transaction in
                        transaction.delete(item)
                    }, completion: { _ in
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

    private func getItem(forIndex: IndexPath) -> Store? {
        return CoreStore.fetchOne(From<Store>().orderBy(.ascending(\.name)).tweak({ fetchRequest in
            fetchRequest.fetchOffset = forIndex.row
            fetchRequest.fetchLimit = 1
        }))
    }

    // MARK: - Navigation

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "editStoreSegue", let controller = segue.destination as? AddStoreViewController, let path = self.tableView.indexPathForSelectedRow, let item = self.getItem(forIndex: path) {
            controller.store = item
        }
    }

    @IBAction func storesList(unwindSegue: UIStoryboardSegue) {
        if unwindSegue.identifier == "addStoreSaveSegue" {
            self.tableView.reloadData()
        }
    }
}
