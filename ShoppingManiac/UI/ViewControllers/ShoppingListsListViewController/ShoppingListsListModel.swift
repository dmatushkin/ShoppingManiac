//
//  ShoppingListsListModel.swift
//  ShoppingManiac
//
//  Created by Dmitry Matyushkin on 09/05/2018.
//  Copyright © 2018 Dmitry Matyushkin. All rights reserved.
//

import Foundation
import CoreStore
import Combine
import UIKit
import CoreData
import CloudKitSync
import DependencyInjection

class ShoppingListsListModel {

	var selectedRow: Int = 0
	private var cancellables = Set<AnyCancellable>()
	@Autowired
	private var cloudShare: CloudKitSyncShareProtocol
	private var dataSource: EditableListDataSource<String, ShoppingList>!
	private let listPublisher = CoreStoreDefaults.dataStack.publishList(From<ShoppingList>().where(Where("isRemoved == false")).orderBy(.descending(\.date)))

	deinit {
		self.listPublisher.removeObserver(self)
	}

	func setupTable(tableView: UITableView) {
		dataSource = EditableListDataSource<String, ShoppingList>(tableView: tableView) {[weak self] (tableView, indexPath, item) -> UITableViewCell? in
			guard let self = self else { return nil }
			if let cell: ShoppingListsListTableViewCell = tableView.dequeueCell(indexPath: indexPath) {
				cell.setup(withList: item, isSelected: indexPath.row == self.selectedRow)
				return cell
			} else {
				fatalError()
			}
		}
		listPublisher.addObserver(self) {[weak self] publisher in
			self?.reloadTable(publisher: publisher)
		}
		reloadTable(publisher: listPublisher)
	}

	private func reloadTable(publisher: ListPublisher<ShoppingList>) {
		var snapshot = NSDiffableDataSourceSnapshot<String, ShoppingList>()
		let section = "Default"
		snapshot.appendSections([section])
		let items = publisher.snapshot.compactMap({ $0.object })
		snapshot.appendItems(items, toSection: section)
		self.dataSource.apply(snapshot, animatingDifferences: false)
	}

    func itemsCount() -> Int {
        return (try? CoreStoreDefaults.dataStack.fetchCount(From<ShoppingList>().where(Where("isRemoved == false")))) ?? 0
    }
    
    func getItem(forIndex: IndexPath) -> ShoppingList? {
		return dataSource.snapshot().itemIdentifiers(inSection: "Default")[forIndex.row]
    }
    
    func deleteItem(shoppingList: ShoppingList) {
        CoreStoreDefaults.dataStack.perform(asynchronous: { transaction in
			let list = transaction.edit(shoppingList)
            list?.isRemoved = true
        }, completion: {[weak self] _ in
            guard let self = self else { return }
            if AppDelegate.discoverabilityStatus && shoppingList.recordid != nil {
				self.cloudShare.updateItem(item: shoppingList).sink(receiveCompletion: {_ in}, receiveValue: {}).store(in: &self.cancellables)
            }
        })
    }
}
