//
//  AddGoodToCategoryModel.swift
//  ShoppingManiac
//
//  Created by Dmitry Matyushkin on 20.05.2021.
//  Copyright © 2021 Dmitry Matyushkin. All rights reserved.
//

import Foundation
import CoreStore

class AddGoodToCategoryModel {
    
    func listAllGoods() -> [String] {
        return (try? CoreStoreDefaults.dataStack.fetchAll(From<Good>().orderBy(.ascending(\.name))))?.compactMap({ $0.name?.nilIfEmpty }) ?? []
    }
}
