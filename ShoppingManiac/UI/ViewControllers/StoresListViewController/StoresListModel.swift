//
//  StoresListModel.swift
//  ShoppingManiac
//
//  Created by Dmitry Matyushkin on 12/05/2018.
//  Copyright © 2018 Dmitry Matyushkin. All rights reserved.
//

import Foundation
import CoreStore
import Combine
import CoreData
import UIKit

class StoresListModel {
    
    private var dataSource: EditableListDataSource<String, Store>!
	private let listPublisher = CoreStoreDefaults.dataStack.publishList(From<Store>().orderBy(.ascending(\.name)))

	deinit {
		self.listPublisher.removeObserver(self)
	}

	func setupTable(tableView: UITableView) {
		dataSource = EditableListDataSource<String, Store>(tableView: tableView) { (tableView, indexPath, item) -> UITableViewCell? in
			if let cell: StoresListTableViewCell = tableView.dequeueCell(indexPath: indexPath) {
				cell.setup(withStore: item)
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

	private func reloadTable(publisher: ListPublisher<Store>) {
		var snapshot = NSDiffableDataSourceSnapshot<String, Store>()
		let section = "Default"
		snapshot.appendSections([section])
		let items = publisher.snapshot.compactMap({ $0.object })
		snapshot.appendItems(items, toSection: section)
		self.dataSource.apply(snapshot, animatingDifferences: false)
	}
    
    func getItem(forIndex: IndexPath) -> Store? {
		return dataSource.snapshot().itemIdentifiers(inSection: "Default")[forIndex.row]
    }
    
    func deleteItem(item: Store) {
        CoreStoreDefaults.dataStack.perform(asynchronous: { transaction in
            transaction.delete(item)
        }, completion: { _ in
        })
    }
}
