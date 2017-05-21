//
//  StoresListTableViewCell.swift
//  ShoppingManiac
//
//  Created by Dmitry Matyushkin on 21/05/2017.
//  Copyright © 2017 Dmitry Matyushkin. All rights reserved.
//

import UIKit

class StoresListTableViewCell: UITableViewCell {

    @IBOutlet weak var storeTitleLabel: UILabel!
    
    override func awakeFromNib() {
        super.awakeFromNib()
    }
    
    func setup(withStore store: Store) {
        self.storeTitleLabel.text = store.name
    }
}
