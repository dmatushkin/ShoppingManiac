//
//  ShoppingListTableViewCell.swift
//  ShoppingManiac
//
//  Created by Dmitry Matyushkin on 21/05/2017.
//  Copyright © 2017 Dmitry Matyushkin. All rights reserved.
//

import UIKit

class ShoppingListTableViewCell: UITableViewCell {

    @IBOutlet private weak var statusImageView: UIImageView!
    @IBOutlet private weak var productTitleLabel: UILabel!
    @IBOutlet private weak var storeTitleLabel: UILabel!
    @IBOutlet private weak var productQuantityLabel: UILabel!
    
    override func awakeFromNib() {
        super.awakeFromNib()
    }

    func setup(withItem item: GroupItem) {
        self.contentView.backgroundColor = item.isCrossListItem ? UIColor(named: "crossListItemColor") : UIColor.clear
        self.statusImageView.image = (item.purchased ? #imageLiteral(resourceName: "checkbox_marked") : #imageLiteral(resourceName: "checkbox_unmarked")).withTintColor(self.itemColor(item: item), renderingMode: .alwaysOriginal)
        self.productTitleLabel.text = item.itemName
        self.storeTitleLabel.text = item.itemCategoryName
        self.productQuantityLabel.text = item.itemQuantityString
        self.productTitleLabel.textColor = self.itemColor(item: item)
        self.storeTitleLabel.textColor = self.itemColor(item: item)
        self.productQuantityLabel.textColor = self.itemColor(item: item)
    }
    
    private func itemColor(item: GroupItem) -> UIColor {
        if item.purchased {
            return UIColor.secondaryLabel
        }
        if item.isImportantItem {
            return UIColor(named: "importantItemColor") ?? UIColor.label
        } else {
            return UIColor.label
        }
    }    
}
