//
//  ListSplitViewController.swift
//  ShoppingManiac
//
//  Created by Dmitry Matyushkin on 9/7/19.
//  Copyright © 2019 Dmitry Matyushkin. All rights reserved.
//

import UIKit

class ListSplitViewController: UISplitViewController, UISplitViewControllerDelegate {

    override func viewDidLoad() {
        super.viewDidLoad()
        self.delegate = self
        self.preferredDisplayMode = .allVisible
    }

    func splitViewController(_ splitViewController: UISplitViewController, collapseSecondary secondaryViewController: UIViewController, onto primaryViewController: UIViewController) -> Bool {
        return true
    }
}
