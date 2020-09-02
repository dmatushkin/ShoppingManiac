//
//  ShoppingListModel.swift
//  ShoppingManiac
//
//  Created by Dmitry Matyushkin on 11/05/2018.
//  Copyright © 2018 Dmitry Matyushkin. All rights reserved.
//

import Foundation
import CoreStore
import Combine
import UIKit
import CloudKitSync
import DependencyInjection

class ShoppingListModel {

	var cancellables = Set<AnyCancellable>()
    @Autowired
	private var cloudShare: CloudKitSyncShareProtocol
	let totalText = CurrentValueSubject<String?, Never>("")

    var shoppingList: ShoppingList?

	private var dataSource: EditableListDataSource<ShoppingGroup, GroupItem>?
	private var listPublisher: ListPublisher<ShoppingListItem>?
	private var goodsPublisher = CoreStoreDefaults.dataStack.publishList(From<Good>().orderBy(.ascending(\.name)))
	private var storesPublisher = CoreStoreDefaults.dataStack.publishList(From<Store>().orderBy(.ascending(\.name)))
	private var categoriesPublisher = CoreStoreDefaults.dataStack.publishList(From<Category>().orderBy(.ascending(\.name)))

	deinit {
		listPublisher?.removeObserver(self)
		goodsPublisher.removeObserver(self)
		storesPublisher.removeObserver(self)
		categoriesPublisher.removeObserver(self)
	}

	func setupTable(tableView: UITableView) {
		guard let shoppingList = self.shoppingList else { return }
		listPublisher = CoreStoreDefaults.dataStack.publishList(shoppingList.itemsFetchBuilder.orderBy(.descending(\.good?.name)))

		dataSource = EditableListDataSource<ShoppingGroup, GroupItem>(tableView: tableView) { (tableView, indexPath, item) -> UITableViewCell? in
			if let cell: ShoppingListTableViewCell = tableView.dequeueCell(indexPath: indexPath) {
				cell.setup(withItem: item)
				return cell
			} else {
				fatalError()
			}
		}
		listPublisher!.addObserver(self, {[weak self] publisher in
			guard let self = self else { return }
			self.reloadTable(publisher: publisher)
		})
		goodsPublisher.addObserver(self, {[weak self] publisher in
			guard let self = self else { return }
			self.reloadTable(publisher: self.listPublisher!)
		})
		storesPublisher.addObserver(self, {[weak self] publisher in
			guard let self = self else { return }
			self.reloadTable(publisher: self.listPublisher!)
		})
		categoriesPublisher.addObserver(self, {[weak self] publisher in
			guard let self = self else { return }
			self.reloadTable(publisher: self.listPublisher!)
		})
		dataSource!.canMoveRow = true
		dataSource!.moveRow = {[weak self] from, to in
			guard let self = self else { return }
			if from.section != to.section {
				self.moveItem(from: from, toGroup: to.section)
			} else {
				self.reloadTable(publisher: self.listPublisher!)
			}
		}
		dataSource!.titleForSection = {[weak self] section in
			guard let self = self else { return nil }
			return self.sectionTitle(forSection: section)
		}
		reloadTable(publisher: listPublisher!)
	}

	private func reloadTable(publisher: ListPublisher<ShoppingListItem>) {
		let items = publisher.snapshot.compactMap({ $0.object })
		let totalPrice = items.reduce(0.0) { acc, curr in
			return acc + curr.totalPrice
		}
		let groups = Set<Store?>(items.map({ $0.store })).sorted(by: {
			($0?.name ?? "") < ($1?.name ?? "")
		}).map({ ShoppingGroup(name: $0?.name, objectId: $0?.objectID)})
		var snapshot = NSDiffableDataSourceSnapshot<ShoppingGroup, GroupItem>()
		snapshot.appendSections(groups)
		for group in groups {
			let groupItems = items.filter({ $0.store?.objectID == group.objectId }).map({ GroupItem(shoppingListItem: $0) }).sorted(by: { $0.lessThan(item: $1) })
			snapshot.appendItems(groupItems, toSection: group)
		}
		self.totalText.send(String(format: "Total: %.2f", totalPrice))
		self.dataSource?.apply(snapshot, animatingDifferences: false)
	}

    func syncWithCloud() {
		guard let shoppingList = self.shoppingList else { return }
        if AppDelegate.discoverabilityStatus && shoppingList.recordid != nil {
			shoppingList.toModel().flatMap({[unowned self] model in
				self.cloudShare.updateItem(item: model).flatMap({_ in
					ShoppingList.storeModel(model: model)
				})
			}).sink(receiveCompletion: {_ in }, receiveValue: {_ in }).store(in: &self.cancellables)
        }
    }
        
    func setLatestList() {
        if let list = try? CoreStoreDefaults.dataStack.fetchOne(From<ShoppingList>().where(Where("isRemoved == false")).orderBy(.descending(\.date))) {
            self.shoppingList = list
        }
    }

    func item(forIndexPath indexPath: IndexPath) -> GroupItem? {
		guard let dataSource = self.dataSource else { return nil }
		let section = dataSource.snapshot().sectionIdentifiers[indexPath.section]
		return dataSource.snapshot().itemIdentifiers(inSection: section)[indexPath.row]
    }
    
    func sectionTitle(forSection section: Int) -> String? {
		return self.dataSource?.snapshot().sectionIdentifiers[section].groupName
    }
    
    func moveItem(from: IndexPath, toGroup: Int) {
		guard let group = self.dataSource?.snapshot().sectionIdentifiers[toGroup], let item = self.item(forIndexPath: from) else { return }

		CoreDataOperationPublisher(operation: {transaction -> Void in
			if let shoppingListItem: ShoppingListItem = transaction.edit(Into<ShoppingListItem>(), item.objectId) {
                if let storeObjectId = group.objectId {
                    shoppingListItem.store = transaction.edit(Into<Store>(), storeObjectId)
                } else {
                    shoppingListItem.store = nil
                }
            }
			}).observeOnMain().sink(receiveCompletion: {_ in }, receiveValue: {[weak self] in
				self?.syncWithCloud()
			}).store(in: &cancellables)
    }

    func togglePurchased(indexPath: IndexPath) {
		guard var item = self.item(forIndexPath: indexPath) else { return }

		item.purchased = !item.purchased

		CoreDataOperationPublisher(operation: {[weak self] transaction -> Void in
			guard let self = self else { return }
			if let shoppingListItem: ShoppingListItem = transaction.edit(Into<ShoppingListItem>(), item.objectId), let shoppingList: ShoppingList = transaction.edit(self.shoppingList) {
                shoppingListItem.purchased = item.purchased
                shoppingListItem.list = shoppingList
            }
			}).observeOnMain().sink(receiveCompletion: {_ in }, receiveValue: {[weak self] in
				self?.syncWithCloud()
			}).store(in: &cancellables)
    }

	func removeItem(from: IndexPath) {
		guard let item = self.item(forIndexPath: from) else { return }
		CoreDataOperationPublisher(operation: {transaction -> Void in
			if let shoppingListItem: ShoppingListItem = transaction.edit(Into<ShoppingListItem>(), item.objectId) {
                shoppingListItem.isRemoved = true
            }
			}).observeOnMain().sink(receiveCompletion: {_ in }, receiveValue: {[weak self] in
				self?.syncWithCloud()
			}).store(in: &cancellables)
	}
}
