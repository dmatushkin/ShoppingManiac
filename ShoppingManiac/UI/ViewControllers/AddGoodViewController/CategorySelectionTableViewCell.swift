//
//  CategorySelectionTableViewCell.swift
//  ShoppingManiac
//
//  Created by Dmitry Matyushkin on 21/05/2017.
//  Copyright © 2017 Dmitry Matyushkin. All rights reserved.
//

import UIKit

class CategorySelectionTableViewCell: UITableViewCell {

    @IBOutlet weak var categoryNameLabel: UILabel!
    
    override func awakeFromNib() {
        super.awakeFromNib()
    }
    
    func setup(withCategory category: Category?) {
        self.categoryNameLabel.text = category?.name ?? "No category"
    }
}
