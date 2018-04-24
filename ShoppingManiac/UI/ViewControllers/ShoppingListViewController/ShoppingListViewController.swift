//
//  ShoppingListViewController.swift
//  ShoppingManiac
//
//  Created by Dmitry Matyushkin on 21/05/2017.
//  Copyright © 2017 Dmitry Matyushkin. All rights reserved.
//

import UIKit
import CoreStore
import MessageUI
import NoticeObserveKit
import SwiftyBeaver
import CloudKit

class ShoppingListViewController: ShoppingManiacViewController, UITableViewDataSource, UITableViewDelegate, MFMessageComposeViewControllerDelegate, UICloudSharingControllerDelegate {

    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var totalLabel: UILabel!

    var shoppingList: ShoppingList!

    var shoppingGroups: [ShoppingGroup] = []

    private var indexPathToEdit: IndexPath?
    private let pool = NoticeObserverPool()

    override func viewDidLoad() {
        super.viewDidLoad()
        self.automaticallyAdjustsScrollViewInsets = false
        self.tableView.setBottomInset(inset: 70)
        self.navigationItem.rightBarButtonItem = self.editButtonItem
        self.reloadData()
        NewDataAvailable.observe {[weak self] _ in
            self?.reloadData()
        }.disposed(by: self.pool)
    }

    override func setEditing(_ editing: Bool, animated: Bool) {
        super.setEditing(editing, animated: true)
        self.tableView.setEditing(editing, animated: animated)
    }

    // MARK: - Data processing

    private func reloadData() {
        if self.shoppingList.recordid != nil {
            CloudShare.updateList(list: self.shoppingList)
        }
        CoreStore.perform(asynchronous: { transaction in
            if let items:[ShoppingListItem] = transaction.fetchAll(From<ShoppingListItem>().where(Where("list = %@", self.shoppingList))) {
                let totalPrice = items.reduce(0.0) { acc, curr in
                    return acc + curr.totalPrice
                }
                var groups: [ShoppingGroup] = []
                for item in items {
                    let storeName = item.store?.name
                    let storeObjectId = item.store?.objectID
                    if let group = groups.filter({ $0.objectId == storeObjectId }).first {
                        group.items.append(GroupItem(shoppingListItem: item))
                    } else {
                        let group = ShoppingGroup(name: storeName, objectId: storeObjectId, items: [GroupItem(shoppingListItem: item)])
                        groups.append(group)
                    }
                }
                self.shoppingGroups = self.sortGroups(groups: groups)
                DispatchQueue.main.async {
                    self.totalLabel.text = String(format: "Total: %.2f", totalPrice)
                }
            } else {
                self.shoppingGroups = []
                DispatchQueue.main.async {
                    self.totalLabel.text = String(format: "Total: %.2f", 0)
                }
            }
        }, completion: { _ in
            self.tableView.reloadData()
        })
    }

    private func sortGroups(groups: [ShoppingGroup]) -> [ShoppingGroup] {
        for group in groups {
            group.items = self.sortItems(items: group.items)
        }
        return groups.sorted(by: {item1, item2 in (item1.groupName ?? "") < (item2.groupName ?? "")})
    }

    private func sortItems(items: [GroupItem]) -> [GroupItem] {
        return items.sorted(by: {item1, item2 in item1.lessThan(item: item2) })
    }

    // MARK: - UITableViewDataSource

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
            fatalError()
        }
    }

    // MARK: - UITableViewDelegate

    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return self.shoppingGroups[section].groupName
    }

    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return self.shoppingGroups[section].groupName == nil ? 0.01 : 44
    }

    func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        return CGFloat.leastNormalMagnitude
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let group = self.shoppingGroups[indexPath.section]
        let item = group.items[indexPath.row]

        item.purchased = !item.purchased
        CoreStore.perform(asynchronous: { transaction in
            if let shoppingListItem: ShoppingListItem = transaction.fetchExisting(item.objectId) {
                shoppingListItem.purchased = item.purchased
            }
        }, completion: {[weak self] _ in
            guard let `self` = self else { return }
            if self.shoppingList.recordid != nil {
                CloudShare.updateList(list: self.shoppingList)
            }
        })
        /*group.items = self.sortItems(items: group.items)
        tableView.reloadData()*/
        let sortedItems = self.sortItems(items: group.items)
        //SwiftyBeaver.debug(sortedItems.map({ $0.itemName }))
        var itemFound: Bool = false
        for (idx, sortedItem) in sortedItems.enumerated() where item.objectId == sortedItem.objectId {
            let sortedIndexPath = IndexPath(row: idx, section: indexPath.section)
            itemFound = true
            group.items = sortedItems
            //SwiftyBeaver.debug("switching \(indexPath.row), \(sortedIndexPath.row)")
            UIView.animate(withDuration: 0.5, animations: { () -> Void in
                self.tableView.moveRow(at: indexPath, to: sortedIndexPath)
            }, completion: { (_) -> Void in
                self.tableView.reloadRows(at: [indexPath, sortedIndexPath], with: UITableViewRowAnimation.none)
            })
            break
        }
        if itemFound == false {
            group.items = sortedItems
            tableView.reloadData()
        }
    }

    func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        return true
    }

    func tableView(_ tableView: UITableView, editActionsForRowAt indexPath: IndexPath) -> [UITableViewRowAction]? {
        let item = self.shoppingGroups[indexPath.section].items[indexPath.row]
        let deleteAction = UITableViewRowAction(style: UITableViewRowActionStyle.default, title: "Delete") { [weak self] _, _ in
            let alertController = UIAlertController(title: "Delete purchase", message: "Are you sure you want to delete \(item.itemName) from your purchase list?", confirmActionTitle: "Delete") {
                self?.tableView.isEditing = false
                CoreStore.perform(asynchronous: { transaction in
                    if let shoppingListItem: ShoppingListItem = transaction.fetchExisting(item.objectId) {
                        transaction.delete(shoppingListItem)
                    }
                }, completion: { [weak self] _ in
                    self?.reloadData()
                })
            }
            self?.present(alertController, animated: true, completion: nil)
        }
        deleteAction.backgroundColor = UIColor.red
        let editAction = UITableViewRowAction(style: UITableViewRowActionStyle.default, title: "Edit") { [weak self] _, indexPath in
            tableView.isEditing = false
            self?.indexPathToEdit = indexPath
            self?.performSegue(withIdentifier: "editShoppingListItemSegue", sender: self)
        }
        editAction.backgroundColor = UIColor.gray

        return [deleteAction, editAction]
    }

    func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCellEditingStyle, forRowAt indexPath: IndexPath) {

    }

    func tableView(_ tableView: UITableView, canMoveRowAt indexPath: IndexPath) -> Bool {
        return true
    }

    func tableView(_ tableView: UITableView, moveRowAt sourceIndexPath: IndexPath, to destinationIndexPath: IndexPath) {
        if sourceIndexPath.section != destinationIndexPath.section {
            let item = self.shoppingGroups[sourceIndexPath.section].items[sourceIndexPath.row]
            CoreStore.perform(asynchronous: { transaction in
                if let shoppingListItem: ShoppingListItem = transaction.fetchExisting(item.objectId) {
                    let destinationGroup = self.shoppingGroups[destinationIndexPath.section]
                    if let storeObjectId = destinationGroup.objectId {
                        shoppingListItem.store = transaction.fetchExisting(storeObjectId)
                    } else {
                        shoppingListItem.store = nil
                    }
                }
            }, completion: { [weak self] _ in
                self?.reloadData()
            })
        }
    }

    // MARK: - Navigation

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "addShoppingListItemSegue", let destination = segue.destination as? AddShoppingItemViewController {
            destination.shoppingList = self.shoppingList
        } else if segue.identifier == "editShoppingListItemSegue", let indexPath = self.indexPathToEdit, let destination = segue.destination as? AddShoppingItemViewController {
            let item = self.shoppingGroups[indexPath.section].items[indexPath.row]
            destination.shoppingListItem = CoreStore.fetchExisting(item.objectId)
            destination.shoppingList = self.shoppingList
        }
    }

    @IBAction func shoppingList(unwindSegue: UIStoryboardSegue) {
        if unwindSegue.identifier == "addShoppingItemSaveSegue" {
            self.reloadData()
        }
    }

    @IBAction func shareAction(_ sender: Any) {
        if AppDelegate.discoverabilityStatus {
            let controller = UIAlertController(title: "Sharing", message: "Select sharing type", preferredStyle: .actionSheet)
            let smsAction = UIAlertAction(title: "Text message", style: .default) {[weak self] _ in
                self?.smsShare()
            }
            let icloudAction = UIAlertAction(title: "iCloud", style: .default) {[weak self] _ in
                self?.icloudShare()
            }
            let cancelAction = UIAlertAction(title: "Cancel", style: .cancel) { _ in

            }
            controller.addAction(smsAction)
            controller.addAction(icloudAction)
            controller.addAction(cancelAction)
            self.present(controller, animated: true, completion: nil)
        } else {
            self.smsShare()
        }
    }

    private func smsShare() {
        if MFMessageComposeViewController.canSendText() {
            let picker = MFMessageComposeViewController()
            picker.messageComposeDelegate = self
            picker.body = self.shoppingList.textData()
            if MFMessageComposeViewController.canSendAttachments() {
                if let data = self.shoppingList.jsonData() {
                    picker.addAttachmentData(data as Data, typeIdentifier: "public.json", filename: "\(self.shoppingList.title).smstorage")
                }
            }
            self.present(picker, animated: true, completion: nil)
        } else {
            let alert = UIAlertController(title: "Error", message: "Unable to send text messages from this device", preferredStyle: .alert)
            let cancelAction = UIAlertAction(title: "Close", style: .default) { _ in
                alert.dismiss(animated: true)
            }
            alert.addAction(cancelAction)
            self.present(alert, animated: true, completion: nil)
        }
    }

    private func icloudShare() {
        let wrapper = CloudShare.shareList(list: self.shoppingList)
        let controller = UICloudSharingController { (_, onDone) in
            CloudShare.createShare(wrapper: wrapper).then({ share in
                CloudShare.updateRecords(wrapper: RecordsWrapper(localDb: true, records: wrapper.items)).then({ error in
                    if let error = error {
                        onDone(nil, CKContainer.default(), error)
                    } else {
                        onDone(share, CKContainer.default(), nil)
                    }
                })
            }).catch({ error in
                onDone(nil, CKContainer.default(), error)
            })
        }
        controller.delegate = self
        controller.availablePermissions = [.allowReadWrite, .allowPublic]
        self.present(controller, animated: true, completion: nil)
    }
    
    // MARK: - Cloud sharing controller delegate
    
    func cloudSharingController(_ csc: UICloudSharingController, failedToSaveShareWithError error: Error) {
        AppDelegate.showAlert(title: "Cloud sharing", message: error.localizedDescription)
    }
    
    func itemTitle(for csc: UICloudSharingController) -> String? {
        return "Shopping list"
    }

    // MARK: - MFMessageComposeViewControllerDelegate

    func messageComposeViewController(_ controller: MFMessageComposeViewController, didFinishWith result: MessageComposeResult) {
        controller.dismiss(animated: true, completion: nil)
    }
}
