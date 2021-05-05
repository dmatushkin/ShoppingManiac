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
import SwiftyBeaver
import CloudKit
import PKHUD
import Combine
import DependencyInjection
import CloudKitSync

class ShoppingListViewController: ShoppingManiacViewController, UITableViewDelegate, MFMessageComposeViewControllerDelegate, UICloudSharingControllerDelegate {

    @IBOutlet private weak var tableView: UITableView!
    @IBOutlet private weak var totalLabel: UILabel!
    @IBOutlet private weak var shareButton: UIButton!
	@IBOutlet private weak var loadingIndicator: UIActivityIndicatorView!
	@IBOutlet private weak var icloudStatusImageView: UIImageView!
    
    let model = ShoppingListModel()
	@Autowired
	private var cloudShare: CloudKitSyncShareProtocol
    
    override func viewDidLoad() {
        super.viewDidLoad()
		self.loadingIndicator.isHidden = true
		self.icloudStatusImageView.isHidden = true
        if self.model.shoppingList == nil {
            self.model.setLatestList()
        }
		self.model.icloudStatus.observeOnMain().sink(receiveValue: {status in
			switch status {
			case .success:
				self.loadingIndicator.stopAnimating()
				self.loadingIndicator.isHidden = true
				self.icloudStatusImageView.isHidden = false
				self.icloudStatusImageView.image = UIImage(systemName: "icloud")
			case .failure:
				self.loadingIndicator.stopAnimating()
				self.loadingIndicator.isHidden = true
				self.icloudStatusImageView.isHidden = false
				self.icloudStatusImageView.image = UIImage(systemName: "exclamationmark.icloud")
			case .inProgress:
				self.loadingIndicator.isHidden = false
				self.loadingIndicator.startAnimating()
				self.icloudStatusImageView.isHidden = true
			case .notApplicable:
				self.loadingIndicator.stopAnimating()
				self.loadingIndicator.isHidden = true
				self.icloudStatusImageView.isHidden = true
			}
		}).store(in: &model.cancellables)
		self.model.setupTable(tableView: tableView)
        self.tableView.contentInsetAdjustmentBehavior = .never
        self.tableView.setBottomInset(inset: 70)
        self.navigationItem.rightBarButtonItem = self.editButtonItem
		self.model.totalText.observeOnMain().assign(to: \.text, on: self.totalLabel).store(in: &model.cancellables)
        if let controllers = self.navigationController?.viewControllers {
            self.navigationController?.viewControllers = controllers.filter({!($0 is AddShoppingListViewController)})
        }
    }

    override func setEditing(_ editing: Bool, animated: Bool) {
        super.setEditing(editing, animated: true)
        self.tableView.setEditing(editing, animated: animated)
    }

    // MARK: - UITableViewDelegate

    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return self.model.sectionTitle(forSection: section) == nil ? 0.01 : 44
    }

    func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        return CGFloat.leastNormalMagnitude
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        self.model.togglePurchased(indexPath: indexPath)
    }

	func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
		guard let item = self.model.item(forIndexPath: indexPath) else { return nil }
		let disableAction = UIContextualAction(style: .destructive, title: "Delete") {[weak self] (_, _, actionPerformed) in
			tableView.isEditing = false
			let alertController = UIAlertController(title: "Delete purchase", message: "Are you sure you want to delete \(item.itemName) from your purchase list?", confirmActionTitle: "Delete") {[weak self] in
				guard let self = self else { return }
				self.tableView.isEditing = false
				self.model.removeItem(from: indexPath)
			}
			self?.present(alertController, animated: true, completion: nil)
			actionPerformed(true)
		}
		let editAction = UIContextualAction(style: .normal, title: "Edit") {[weak self] (_, _, actionPerformed) in
			tableView.isEditing = false
            self?.performSegue(withIdentifier: "editShoppingListItemSegue", sender: indexPath)
			actionPerformed(true)
		}
		return UISwipeActionsConfiguration(actions: [disableAction, editAction])
	}

    // MARK: - Navigation

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "addShoppingListItemSegue", let destination = segue.destination as? AddShoppingItemViewController {
            destination.model.shoppingList = self.model.shoppingList
        } else if segue.identifier == "editShoppingListItemSegue", let indexPath = sender as? IndexPath, let destination = segue.destination as? AddShoppingItemViewController, let item = self.model.item(forIndexPath: indexPath) {
            destination.model.shoppingListItem = CoreStoreDefaults.dataStack.fetchExisting(item.objectId)
            destination.model.shoppingList = self.model.shoppingList
        }
    }

    @IBAction private func shoppingList(unwindSegue: UIStoryboardSegue) {
		if unwindSegue.identifier == "addShoppingItemSaveSegue" {
			self.model.syncWithCloud()
		}
    }

    @IBAction private func shareAction(_ sender: Any) {
        if AppDelegate.discoverabilityStatus {
            let style: UIAlertController.Style
            #if targetEnvironment(macCatalyst)
            style = .alert
            #else
            if UIDevice.current.userInterfaceIdiom == .phone {
                style = .actionSheet
            } else {
                style = .alert
            }
            #endif
            let controller = UIAlertController(title: "Sharing", message: "Select sharing type", preferredStyle: style)
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
            controller.popoverPresentationController?.sourceView = self.shareButton
            controller.popoverPresentationController?.sourceRect = self.shareButton.frame
            self.present(controller, animated: true, completion: nil)
        } else {
            self.smsShare()
        }
    }

    private func smsShare() {
		guard let shoppingList = self.model.shoppingList else { return }
        if MFMessageComposeViewController.canSendText() {
            let picker = MFMessageComposeViewController()
            picker.messageComposeDelegate = self
            picker.body = shoppingList.textData()
            if MFMessageComposeViewController.canSendAttachments() {
                if let data = shoppingList.jsonData() {
                    picker.addAttachmentData(data as Data, typeIdentifier: "public.json", filename: "\(shoppingList.title).smstorage")
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
		guard let shoppingList = self.model.shoppingList else { return }
        HUD.show(.labeledProgress(title: "Creating share", subtitle: nil))
		self.cloudShare.shareItem(item: shoppingList, shareTitle: "Shopping List", shareType: "org.md.ShoppingManiac").observeOnMain().sink(receiveCompletion: {[weak self] completion in
			HUD.hide()
			guard let self = self else { return }
			switch completion {
			case .failure(let error):
				self.model.icloudStatus.value = .failure(error)
				AppDelegate.showAlert(title: "iCloud sharing error", message: error.localizedDescription)
			case .finished:
				self.model.icloudStatus.value = .success
			}
		}, receiveValue: {[weak self] value in
			self?.createSharingController(share: value)
		}).store(in: &self.model.cancellables)
    }
    
    private func createSharingController(share: CKShare) {
        let controller = UICloudSharingController(share: share, container: CKContainer.default())
        controller.delegate = self
        controller.availablePermissions = [.allowReadWrite, .allowPublic]
        controller.popoverPresentationController?.sourceView = self.shareButton
        controller.popoverPresentationController?.sourceRect = self.shareButton.frame
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
