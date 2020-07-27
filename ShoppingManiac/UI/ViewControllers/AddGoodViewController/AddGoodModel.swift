//
//  AddGoodModel.swift
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

class AddGoodModel {

    var good: Good?
    var category: Category? = nil {
        didSet {
            self.goodCategory.send(category?.name ?? "")
        }
    }
	private let categoriesPublisher = CoreStoreDefaults.dataStack.publishList(From<Category>().orderBy(.ascending(\.name)))
	private var dataSource: EditableListDataSource<String, Category>!
    
    let goodName = CurrentValueSubject<String?, Never>("")
    let goodCategory = CurrentValueSubject<String?, Never>("")
    let rating = CurrentValueSubject<Int, Never>(0)

	deinit {
		self.categoriesPublisher.removeObserver(self)
	}

	func setupTable(tableView: UITableView) {
		dataSource = EditableListDataSource<String, Category>(tableView: tableView) { (tableView, indexPath, item) -> UITableViewCell? in
			if let cell: CategorySelectionTableViewCell = tableView.dequeueCell(indexPath: indexPath) {
				cell.setup(withCategory: item)
				return cell
			} else {
				fatalError()
			}
		}
		categoriesPublisher.addObserver(self) {[weak self] publisher in
			self?.reloadTable(publisher: publisher)
		}
		reloadTable(publisher: categoriesPublisher)
	}

	private func reloadTable(publisher: ListPublisher<Category>) {
		var snapshot = NSDiffableDataSourceSnapshot<String, Category>()
		let section = "Default"
		snapshot.appendSections([section])
		let items = publisher.snapshot.compactMap({ $0.object })
		snapshot.appendItems(items, toSection: section)
		self.dataSource.apply(snapshot, animatingDifferences: false)
	}
    
    func applyData() {
        self.goodName.send(self.good?.name ?? "")
        self.goodCategory.send(self.good?.category?.name ?? "")
        self.category = good?.category
        self.rating.send(Int(good?.personalRating ?? 0))
    }
    
	func persistChangesAsync() -> AnyPublisher<Void, Error> {
		if let good = self.good {
			return self.updateItemAsync(item: good, withName: self.goodName.value)
		} else {
			return self.createItemAsync(withName: self.goodName.value)
		}
	}

	private func createItemAsync(withName name: String?) -> AnyPublisher<Void, Error> {
		return CoreDataOperationPublisher(operation: {[weak self] transaction -> Void in
			guard let self = self else { return }
			let item = transaction.create(Into<Good>())
            item.name = name
			item.category = transaction.edit(self.category)
            item.personalRating = Int16(self.rating.value)
			}).eraseToAnyPublisher()
	}

	private func updateItemAsync(item: Good, withName name: String?) -> AnyPublisher<Void, Error> {
		return CoreDataOperationPublisher(operation: {[weak self] transaction -> Void in
			guard let self = self else { return }
			let item = transaction.edit(item)
            item?.name = name
            item?.category = transaction.edit(self.category)
            item?.personalRating = Int16(self.rating.value)
		}).eraseToAnyPublisher()
	}

	func clearCategory() {
		self.category = nil
	}

    func categoriesCount() -> Int {
		return dataSource.snapshot().numberOfItems
    }
    
    func getCategoryItem(forIndex: IndexPath) -> Category? {
		return dataSource.snapshot().itemIdentifiers(inSection: "Default")[forIndex.row]
    }
}
