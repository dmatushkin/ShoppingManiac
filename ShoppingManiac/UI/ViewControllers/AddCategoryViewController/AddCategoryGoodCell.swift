//
//  AddCategoryGoodCell.swift
//  ShoppingManiac
//
//  Created by Dmitry Matyushkin on 20.05.2021.
//  Copyright © 2021 Dmitry Matyushkin. All rights reserved.
//

import UIKit

class AddCategoryGoodCell: UITableViewCell {

    @IBOutlet private weak var titleLabel: UILabel!

    override func awakeFromNib() {
        super.awakeFromNib()
    }
    
    func setup(title: String) {
        self.titleLabel.text = title
    }
}
