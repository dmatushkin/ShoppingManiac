//
//  ShoppingListsListTableViewCell.swift
//  ShoppingManiac
//
//  Created by Dmitry Matyushkin on 21/05/2017.
//  Copyright © 2017 Dmitry Matyushkin. All rights reserved.
//

import UIKit

class ShoppingListsListTableViewCell: UITableViewCell {

    @IBOutlet weak var listTitleLabel: UILabel!
    
    override func awakeFromNib() {
        super.awakeFromNib()
    }
    
    func setup(withList shoppingList: ShoppingList) {
        self.listTitleLabel.text = shoppingList.title
        self.listTitleLabel.textColor = shoppingList.isPurchased ? UIColor.gray : UIColor.black
    }
}
