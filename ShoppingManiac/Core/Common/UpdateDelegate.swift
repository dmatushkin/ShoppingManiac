//
//  UpdateDelegate.swift
//  ShoppingManiac
//
//  Created by Dmitry Matyushkin on 9/17/19.
//  Copyright © 2019 Dmitry Matyushkin. All rights reserved.
//

import Foundation

protocol UpdateDelegate: AnyObject {
    func reloadData()
    func moveRow(fromPath: IndexPath, toPath: IndexPath)
}
