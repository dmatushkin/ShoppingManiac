//
//  AddCategoryToStoreModel.swift
//  ShoppingManiac
//
//  Created by Dmitry Matyushkin on 19.05.2021.
//  Copyright © 2021 Dmitry Matyushkin. All rights reserved.
//

import Foundation
import CoreStore

class AddCategoryToStoreModel {
    
    func listAllCategories() -> [String] {
        return (try? CoreStoreDefaults.dataStack.fetchAll(From<Category>().orderBy(.ascending(\.name))))?.compactMap({ $0.name?.nilIfEmpty }) ?? []
    }
}
