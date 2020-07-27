//
//  CategoriesListModel.swift
//  ShoppingManiac
//
//  Created by Dmitry Matyushkin on 12/05/2018.
//  Copyright © 2018 Dmitry Matyushkin. All rights reserved.
//

import Foundation
import CoreStore
import CoreData
import Combine
import UIKit

class CategoriesListModel {

	private var dataSource: EditableListDataSource<String, Category>!
	private let listPublisher = CoreStoreDefaults.dataStack.publishList(From<Category>().orderBy(.ascending(\.name)))

	deinit {
		self.listPublisher.removeObserver(self)
	}

	func setupTable(tableView: UITableView) {
		dataSource = EditableListDataSource<String, Category>(tableView: tableView) { (tableView, indexPath, item) -> UITableViewCell? in
			if let cell: CategoriesListTableViewCell = tableView.dequeueCell(indexPath: indexPath) {
				cell.setup(withCategory: item)
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

	private func reloadTable(publisher: ListPublisher<Category>) {
		var snapshot = NSDiffableDataSourceSnapshot<String, Category>()
		let section = "Default"
		snapshot.appendSections([section])
		let items = publisher.snapshot.compactMap({ $0.object })
		snapshot.appendItems(items, toSection: section)
		self.dataSource.apply(snapshot, animatingDifferences: false)
	}

    func getItem(forIndex: IndexPath) -> Category? {
		return listPublisher.snapshot[forIndex.row].object
    }
    
    func deleteItem(item: Category) {
        CoreStoreDefaults.dataStack.perform(asynchronous: { transaction in
			transaction.delete(item)
        }, completion: { _ in
        })
    }
}
