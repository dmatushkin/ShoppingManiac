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
        self.statusImageView.image = item.purchased ? #imageLiteral(resourceName: "checkbox_marked") : #imageLiteral(resourceName: "checkbox_unmarked")
        self.productTitleLabel.text = item.itemName
        self.storeTitleLabel.text = item.itemCategoryName
        self.productQuantityLabel.text = item.itemQuantityString
        self.productTitleLabel.textColor = item.purchased ? UIColor.gray : UIColor.black
        self.storeTitleLabel.textColor = item.purchased ? UIColor.gray : UIColor.black
        self.productQuantityLabel.textColor = item.purchased ? UIColor.gray : UIColor.black
    }
}
