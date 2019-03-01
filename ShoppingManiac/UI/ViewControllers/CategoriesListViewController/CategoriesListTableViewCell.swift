//
//  CategoriesListTableViewCell.swift
//  ShoppingManiac
//
//  Created by Dmitry Matyushkin on 21/05/2017.
//  Copyright © 2017 Dmitry Matyushkin. All rights reserved.
//

import UIKit

class CategoriesListTableViewCell: UITableViewCell {

    @IBOutlet private weak var categoryTitleLabel: UILabel!

    override func awakeFromNib() {
        super.awakeFromNib()
    }

    func setup(withCategory category: Category) {
        self.categoryTitleLabel.text = category.name
    }
}
