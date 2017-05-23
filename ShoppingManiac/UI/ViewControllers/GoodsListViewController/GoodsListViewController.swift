//
//  GoodsListViewController.swift
//  ShoppingManiac
//
//  Created by Dmitry Matyushkin on 21/05/2017.
//  Copyright © 2017 Dmitry Matyushkin. All rights reserved.
//

import UIKit
import CoreStore

class GoodsListViewController: UIViewController, UITableViewDelegate, UITableViewDataSource {

    @IBOutlet weak var tableView: UITableView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.automaticallyAdjustsScrollViewInsets = false
    }
    
    public func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return CoreStore.fetchCount(From<Good>(), []) ?? 0
    }
    
    public func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if let item = self.getItem(forIndex: indexPath), let cell: GoodsListTableViewCell = tableView.dequeueCell(indexPath: indexPath) {
            cell.setup(withGood: item)
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
            if let good = self.getItem(forIndex: indexPath) {
                let alertController = UIAlertController(title: "Delete good", message: "Are you sure you want to delete \(good.name ?? "this good")?", confirmActionTitle: "Delete") {
                    CoreStore.beginAsynchronous { (transaction) in
                        transaction.delete(good)
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
    
    private func getItem(forIndex: IndexPath) -> Good? {
        return CoreStore.fetchOne(From<Good>(), OrderBy(.ascending("name")), Tweak({ fetchRequest in
            fetchRequest.fetchOffset = forIndex.row
        }))
    }
    
    // MARK: - Navigation
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "editGoodSegue", let controller = segue.destination as? AddGoodViewController, let path = self.tableView.indexPathForSelectedRow, let item = self.getItem(forIndex: path) {
            controller.good = item
        }
    }
    
    @IBAction func goodsList(unwindSegue: UIStoryboardSegue) {
        if unwindSegue.identifier == "addGoodSaveSegue" {
            self.tableView.reloadData()
        }
    }
}
