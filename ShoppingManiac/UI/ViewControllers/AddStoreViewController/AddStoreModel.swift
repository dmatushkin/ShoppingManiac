//
//  AddStoreModel.swift
//  ShoppingManiac
//
//  Created by Dmitry Matyushkin on 12/05/2018.
//  Copyright © 2018 Dmitry Matyushkin. All rights reserved.
//

import Foundation
import Combine
import CoreStore
import UIKit

class AddStoreModel {
    
    class CategoriesTableDataSource: NSObject, UITableViewDataSource {
        
        weak var model: AddStoreModel?
                
        func numberOfSections(in tableView: UITableView) -> Int {
            return 1
        }
        
        func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
            return self.model?.categories.count ?? 0
        }
        
        func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
            guard let cell: AddStoreCategoryCell = tableView.dequeueCell(indexPath: indexPath) else { fatalError() }
            if let title = self.model?.categories[indexPath.row] {
                cell.setup(title: title)
            }
            return cell
        }
        
        func tableView(_ tableView: UITableView, canMoveRowAt indexPath: IndexPath) -> Bool {
            return true
        }
        
        func tableView(_ tableView: UITableView, moveRowAt sourceIndexPath: IndexPath, to destinationIndexPath: IndexPath) {
            guard let model = self.model else { return }
            let sourceRow = sourceIndexPath.row
            let destRow = destinationIndexPath.row
            let value = model.categories.remove(at: sourceRow)
            if destRow > sourceRow {
                model.categories.insert(value, at: destRow - 1)
            } else {
                model.categories.insert(value, at: destRow)
            }
        }
    }
    
    class CategoriesTableDelegate: NSObject, UITableViewDelegate {
        
        weak var model: AddStoreModel?
        
        func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
            guard let model = model else { return nil }
            let disableAction = UIContextualAction(style: .destructive, title: "Remove") { (_, _, actionPerformed) in
                model.categories.remove(at: indexPath.row)
                model.needsTableReload?()
                actionPerformed(true)
            }
            return UISwipeActionsConfiguration(actions: [disableAction])
        }
        
        func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
            return CGFloat.leastNormalMagnitude
        }
    }
    
    private var categories: [String] = []
    
    var store: Store?
    
    var cancellables = Set<AnyCancellable>()
    
    let storeName = CurrentValueSubject<String?, Never>("")
    
    let dataSource: CategoriesTableDataSource
    let dataHandler: CategoriesTableDelegate
    
    var needsTableReload: (() -> Void)?
    
    init() {
        self.dataSource = CategoriesTableDataSource()
        self.dataHandler = CategoriesTableDelegate()
        self.dataSource.model = self
        self.dataHandler.model = self
    }
    
    func applyData() {
        self.storeName.send(self.store?.name ?? "")
        self.categories = self.store?.listCategories.compactMap({ $0.name?.nilIfEmpty }) ?? []
    }
    
    func appendCategory(name: String) {
        self.categories.append(name)
        self.needsTableReload?()
    }
    
	func persistDataAsync() -> AnyPublisher<Void, Error> {
		return CoreDataOperationPublisher(operation: {[weak self] transaction -> Void in
			guard let self = self else { return }
			let item = self.store.flatMap({ transaction.edit($0) }) ?? transaction.create(Into<Store>())
			item.name = self.storeName.value
            let categoriesToAdd: [CategoryStoreOrder] = self.categories.enumerated().compactMap({ (order, name) -> CategoryStoreOrder? in
                let categoryOrder: CategoryStoreOrder? = (item.orders as? Set<CategoryStoreOrder>)?.first(where: { $0.category?.name == name }) ?? {
                    do {
                        let category = try transaction.fetchOne(From<Category>().where(Where("name == %@", name))) ?? transaction.create(Into<Category>())
                        category.name = name
                        let categoryOrder = transaction.create(Into<CategoryStoreOrder>())
                        categoryOrder.category = category
                        categoryOrder.store = item
                        return categoryOrder
                    } catch {
                        return nil
                    }
                }()
                categoryOrder?.order = Int64(order)
                return categoryOrder
            })
            let categoriesToRemove = (item.orders as? Set<CategoryStoreOrder>)?.filter({ !self.categories.contains($0.category?.name ?? "")}) ?? []
            item.removeFromOrders(NSSet(array: categoriesToRemove))
            item.addToOrders(NSSet(array: categoriesToAdd))
		}).eraseToAnyPublisher()
	}
}
