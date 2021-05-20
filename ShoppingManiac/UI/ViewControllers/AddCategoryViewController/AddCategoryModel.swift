//
//  AddCategoryModel.swift
//  ShoppingManiac
//
//  Created by Dmitry Matyushkin on 12/05/2018.
//  Copyright © 2018 Dmitry Matyushkin. All rights reserved.
//

import Foundation
import CoreStore
import Combine
import UIKit

class AddCategoryModel {
    
    class GoodsTableDataSource: NSObject, UITableViewDataSource {
        
        weak var model: AddCategoryModel?
                
        func numberOfSections(in tableView: UITableView) -> Int {
            return 1
        }
        
        func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
            return self.model?.goods.count ?? 0
        }
        
        func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
            guard let cell: AddCategoryGoodCell = tableView.dequeueCell(indexPath: indexPath) else { fatalError() }
            if let title = self.model?.goods[indexPath.row] {
                cell.setup(title: title)
            }
            return cell
        }
    }
    
    class GoodsTableDelegate: NSObject, UITableViewDelegate {
        
        weak var model: AddCategoryModel?
        
        func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
            guard let model = model else { return nil }
            let disableAction = UIContextualAction(style: .destructive, title: "Remove") { (_, _, actionPerformed) in
                model.goods.remove(at: indexPath.row)
                model.needsTableReload?()
                actionPerformed(true)
            }
            return UISwipeActionsConfiguration(actions: [disableAction])
        }
        
        func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
            return CGFloat.leastNormalMagnitude
        }
    }
    
    private var goods: [String] = []
    
    var category: Category?
    
    var cancellables = Set<AnyCancellable>()
    
    let categoryName = CurrentValueSubject<String?, Never>("")
    
    let dataSource: GoodsTableDataSource
    let dataHandler: GoodsTableDelegate
    
    var needsTableReload: (() -> Void)?
    
    init() {
        self.dataSource = GoodsTableDataSource()
        self.dataHandler = GoodsTableDelegate()
        self.dataSource.model = self
        self.dataHandler.model = self
    }
    
    func applyData() {
        self.categoryName.send(self.category?.name ?? "")
        self.goods = self.category?.listGoods.compactMap({ $0.name?.nilIfEmpty }).sorted() ?? []
    }
    
	func persistDataAsync() -> AnyPublisher<Void, Error> {
		return CoreDataOperationPublisher(operation: {[weak self] transaction -> Void in
			guard let self = self else { return }
			let item = self.category.flatMap({ transaction.edit($0) }) ?? transaction.create(Into<Category>())
			item.name = self.categoryName.value
            let goodsToAdd = self.goods.compactMap({ goodName -> Good? in
                do {
                    let good = try transaction.fetchOne(From<Good>().where(Where("name == %@", goodName))) ?? transaction.create(Into<Good>())
                    good.name = goodName
                    return good
                } catch {
                    return nil
                }
            })
            let goodsToRemove = item.listGoods.filter({ !self.goods.contains($0.name ?? "") })
            item.removeFromGoods(NSSet(array: goodsToRemove))
            item.addToGoods(NSSet(array: goodsToAdd))
		}).eraseToAnyPublisher()
	}
    
    func appendGood(name: String) {
        self.goods.append(name)
        self.goods = self.goods.sorted()
        self.needsTableReload?()
    }
}
