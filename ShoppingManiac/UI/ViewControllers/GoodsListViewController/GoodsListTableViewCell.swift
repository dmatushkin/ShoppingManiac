//
//  GoodsListTableViewCell.swift
//  ShoppingManiac
//
//  Created by Dmitry Matyushkin on 21/05/2017.
//  Copyright © 2017 Dmitry Matyushkin. All rights reserved.
//

import UIKit

class GoodsListTableViewCell: UITableViewCell {

    @IBOutlet weak var goodTitleLabel: UILabel!
    
    override func awakeFromNib() {
        super.awakeFromNib()
    }
    
    func setup(withGood good: Good) {
        self.goodTitleLabel.text = good.name
    }
}
