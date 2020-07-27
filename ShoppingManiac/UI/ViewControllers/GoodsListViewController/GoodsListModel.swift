//
//  GoodsListModel.swift
//  ShoppingManiac
//
//  Created by Dmitry Matyushkin on 12/05/2018.
//  Copyright © 2018 Dmitry Matyushkin. All rights reserved.
//

import Foundation
import CoreStore
import Combine
import UIKit
import CoreData

class GoodsListModel {
    
	private var dataSource: EditableListDataSource<String, Good>!
	private let listPublisher = CoreStoreDefaults.dataStack.publishList(From<Good>().orderBy(.ascending(\.name)))

	deinit {
		self.listPublisher.removeObserver(self)
	}

	func setupTable(tableView: UITableView) {
		dataSource = EditableListDataSource<String, Good>(tableView: tableView) { (tableView, indexPath, item) -> UITableViewCell? in
			if let cell: GoodsListTableViewCell = tableView.dequeueCell(indexPath: indexPath) {
				cell.setup(withGood: item)
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

	private func reloadTable(publisher: ListPublisher<Good>) {
		var snapshot = NSDiffableDataSourceSnapshot<String, Good>()
		let section = "Default"
		snapshot.appendSections([section])
		let items = publisher.snapshot.compactMap({ $0.object })
		snapshot.appendItems(items, toSection: section)
		self.dataSource.apply(snapshot, animatingDifferences: false)
	}
    
    func getItem(forIndex: IndexPath) -> Good? {
		return dataSource.snapshot().itemIdentifiers(inSection: "Default")[forIndex.row]
    }
    
    func deleteItem(good: Good) {
        CoreStoreDefaults.dataStack.perform(asynchronous: { transaction in
            transaction.delete(good)
        }, completion: { _ in
        })
    }
}
