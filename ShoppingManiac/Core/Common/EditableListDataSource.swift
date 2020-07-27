//
//  EditableListDataSource.swift
//  ShoppingManiac
//
//  Created by Dmitry Matyushkin on 7/27/20.
//  Copyright © 2020 Dmitry Matyushkin. All rights reserved.
//

import UIKit

final class EditableListDataSource<S: Hashable, I: Hashable>: UITableViewDiffableDataSource<S, I> {

	var editable: Bool = true
	var canMoveRow: Bool = false

	var titleForSection: ((Int) -> String?)?
	var moveRow: ((IndexPath, IndexPath) -> Void)?

	override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
		return editable
	}

	override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
		return self.titleForSection?(section)
	}

	override func tableView(_ tableView: UITableView, canMoveRowAt indexPath: IndexPath) -> Bool {
		return canMoveRow
	}

	override func tableView(_ tableView: UITableView, moveRowAt sourceIndexPath: IndexPath, to destinationIndexPath: IndexPath) {
		moveRow?(sourceIndexPath, destinationIndexPath)
	}
}
