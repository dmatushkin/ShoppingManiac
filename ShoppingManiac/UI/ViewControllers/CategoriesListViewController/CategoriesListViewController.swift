//
//  CategoriesListViewController.swift
//  ShoppingManiac
//
//  Created by Dmitry Matyushkin on 21/05/2017.
//  Copyright © 2017 Dmitry Matyushkin. All rights reserved.
//

import UIKit
import CoreStore
import NoticeObserveKit

class CategoriesListViewController: UIViewController, UITableViewDelegate, UITableViewDataSource {

    @IBOutlet weak var tableView: UITableView!
    
    private let pool = NoticeObserverPool()

    override func viewDidLoad() {
        super.viewDidLoad()
        self.automaticallyAdjustsScrollViewInsets = false
        NewDataAvailable.observe {[weak self] _ in
            self?.tableView.reloadData()
        }.disposed(by: self.pool)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.tableView.reloadData()
    }

    public func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return CoreStore.fetchCount(From<Category>(), []) ?? 0
    }

    public func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if let item = self.getItem(forIndex: indexPath), let cell: CategoriesListTableViewCell = tableView.dequeueCell(indexPath: indexPath) {
            cell.setup(withCategory: item)
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
            if let item = self.getItem(forIndex: indexPath) {
                let alertController = UIAlertController(title: "Delete category", message: "Are you sure you want to delete \(item.name ?? "category")?", confirmActionTitle: "Delete") {
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

    private func getItem(forIndex: IndexPath) -> Category? {
        return CoreStore.fetchOne(From<Category>().orderBy(.ascending(\.name)).tweak({ fetchRequest in
            fetchRequest.fetchOffset = forIndex.row
            fetchRequest.fetchLimit = 1
        }))
    }

    // MARK: - Navigation

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "editCateogrySegue", let controller = segue.destination as? AddCategoryViewController, let path = self.tableView.indexPathForSelectedRow, let item = self.getItem(forIndex: path) {
            controller.category = item
        }
    }

    @IBAction func categoriesList(unwindSegue: UIStoryboardSegue) {
        if unwindSegue.identifier == "addCategorySaveSegue" {
            self.tableView.reloadData()
        }
    }
}
