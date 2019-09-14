//
//  StoresListViewController.swift
//  ShoppingManiac
//
//  Created by Dmitry Matyushkin on 21/05/2017.
//  Copyright © 2017 Dmitry Matyushkin. All rights reserved.
//

import UIKit

class StoresListViewController: ShoppingManiacViewController, UITableViewDataSource, UITableViewDelegate {

    @IBOutlet private weak var tableView: UITableView!
    private let model = StoresListModel()

    override func viewDidLoad() {
        super.viewDidLoad()
        self.tableView.contentInsetAdjustmentBehavior = .never
        self.model.onUpdate = {[weak self] in
            self?.tableView.reloadData()
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.tableView.reloadData()
    }

    public func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return self.model.itemsCount()
    }

    public func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if let item = self.model.getItem(forIndex: indexPath), let cell: StoresListTableViewCell = tableView.dequeueCell(indexPath: indexPath) {
            cell.setup(withStore: item)
            return cell
        } else {
            fatalError()
        }
    }

    func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        return true
    }

    func tableView(_ tableView: UITableView, editActionsForRowAt indexPath: IndexPath) -> [UITableViewRowAction]? {
        let disableAction = UITableViewRowAction(style: UITableViewRowAction.Style.default, title: "Delete") { [unowned self] _, indexPath in
            tableView.isEditing = false
            if let item = self.model.getItem(forIndex: indexPath) {
                let alertController = UIAlertController(title: "Delete store", message: "Are you sure you want to delete \(item.name ?? "store")?", confirmActionTitle: "Delete") {[weak self] in
                    self?.model.deleteItem(item: item)
                }
                self.present(alertController, animated: true, completion: nil)
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

    // MARK: - Navigation

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "editStoreSegue", let controller = segue.destination as? AddStoreViewController, let path = self.tableView.indexPathForSelectedRow, let item = self.model.getItem(forIndex: path) {
            controller.model.store = item
        }
    }

    @IBAction private func storesList(unwindSegue: UIStoryboardSegue) {
        if unwindSegue.identifier == "addStoreSaveSegue" {
            self.tableView.reloadData()
        }
    }
}
