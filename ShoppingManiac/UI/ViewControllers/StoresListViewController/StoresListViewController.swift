//
//  StoresListViewController.swift
//  ShoppingManiac
//
//  Created by Dmitry Matyushkin on 21/05/2017.
//  Copyright © 2017 Dmitry Matyushkin. All rights reserved.
//

import UIKit
import CoreStore

class StoresListViewController: ShoppingManiacViewController, UITableViewDelegate {

    @IBOutlet private weak var tableView: UITableView!
    private let model = StoresListModel()

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
			if let item = self?.model.getItem(forIndex: indexPath) {
                let alertController = UIAlertController(title: "Delete store", message: "Are you sure you want to delete \(item.name ?? "store")?", confirmActionTitle: "Delete") {[weak self] in
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
