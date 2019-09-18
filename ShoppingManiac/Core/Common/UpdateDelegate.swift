//
//  UpdateDelegate.swift
//  ShoppingManiac
//
//  Created by Dmitry Matyushkin on 9/17/19.
//  Copyright © 2019 Dmitry Matyushkin. All rights reserved.
//

import Foundation

protocol UpdateDelegate: class {
    func reloadData()
    func moveRow(from: IndexPath, to: IndexPath)
}
