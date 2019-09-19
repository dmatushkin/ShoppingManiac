//
//  ShoppingListsListTableViewCell.swift
//  ShoppingManiac
//
//  Created by Dmitry Matyushkin on 21/05/2017.
//  Copyright © 2017 Dmitry Matyushkin. All rights reserved.
//

import UIKit

class ShoppingListsListTableViewCell: UITableViewCell {

    @IBOutlet private weak var listTitleLabel: UILabel!
    @IBOutlet private weak var cloudIconView: UIImageView!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        if UIDevice.current.userInterfaceIdiom == .phone {
            self.selectionStyle = .none
        } else {
            self.selectionStyle = .gray
        }
    }

    func setup(withList shoppingList: ShoppingList, isSelected: Bool) {
        self.listTitleLabel.text = shoppingList.title
        self.cloudIconView.isHidden = !shoppingList.isRemote
        self.listTitleLabel.textColor = shoppingList.isPurchased ? UIColor.gray : UIColor.black
        if UIDevice.current.userInterfaceIdiom == .phone || isSelected == false {
            self.backgroundColor = UIColor.clear
        } else {
            self.backgroundColor = UIColor.lightGray.withAlphaComponent(0.5)
        }
    }
}
