//
//  AutocompleteTextField.swift
//  ShoppingManiac
//
//  Created by Dmitry Matyushkin on 28/05/2017.
//  Copyright © 2017 Dmitry Matyushkin. All rights reserved.
//

import UIKit
import NoticeObserveKit

class AutocompleteTextField: RoundRectTextField, UITableViewDelegate, UITableViewDataSource {

    private let autocompleteTable = UITableView()

    var autocompleteStrings: [String] = []

    private var keyboardHeight: CGFloat = 0
    private var pool = NoticeObserverPool()

    override init(frame: CGRect) {
        super.init(frame: frame)
        self.setup()
    }

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        self.setup()
    }

    private func setup() {
        self.clipsToBounds = false
        self.autocompleteTable.rowHeight = 44
        self.autocompleteTable.delegate = self
        self.autocompleteTable.dataSource = self
        self.autocompleteTable.isUserInteractionEnabled = true
        self.autocompleteTable.allowsSelection = true
        self.autocompleteTable.allowsMultipleSelection = false
        self.autocompleteTable.register(UITableViewCell.self, forCellReuseIdentifier: "autocompleteCell")
        self.autocompleteTable.backgroundColor = UIColor.clear
        self.autocompleteTable.layer.cornerRadius = 5
        self.autocompleteTable.layer.borderColor = UIColor.gray.cgColor
        self.autocompleteTable.layer.borderWidth = 1
        self.setBottomOffset(keyboardInfo: UIKeyboardInfo(info: [:]))
        UIKeyboardWillChangeFrame.observe { keyboardInfo in
            self.setBottomOffset(keyboardInfo: keyboardInfo)
            }.addObserverTo(pool)
        UIKeyboardWillHide.observe { keyboardInfo in
            self.setBottomOffset(keyboardInfo: UIKeyboardInfo(info: [:]))
            }.addObserverTo(pool)
    }

    private func item(forIndexPath indexPath: IndexPath) -> String {
        return self.autocompleteStrings.filter({ $0.contains(self.text ?? "") })[indexPath.row]
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return self.autocompleteStrings.filter({ $0.contains(self.text ?? "") }).count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "autocompleteCell", for: indexPath)
        cell.selectionStyle = .none
        cell.textLabel?.text = self.item(forIndexPath: indexPath)
        return cell
    }

    func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        return CGFloat.leastNormalMagnitude
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        self.text = self.item(forIndexPath: indexPath)
        self.autocompleteTable.removeFromSuperview()
    }

    override func editingChanged() {
        super.editingChanged()
        if self.autocompleteTable.superview == nil {
            self.superview?.addSubview(self.autocompleteTable)
            self.superview?.bringSubview(toFront: self.autocompleteTable)
        }
        self.layoutAutocompleteTable()
        self.autocompleteTable.reloadData()
    }

    private func layoutAutocompleteTable() {
        let frame = self.frame
        let screenHeight = UIScreen.main.bounds.height
        let availableHeight = screenHeight - self.keyboardHeight - self.frame.origin.y - self.frame.size.height
        if frame.origin.y > (availableHeight - frame.origin.y - frame.size.height) { //appears from top of the field
            let height = min(frame.origin.y, CGFloat(self.tableView(self.autocompleteTable, numberOfRowsInSection: 0)) * self.autocompleteTable.rowHeight)
            self.autocompleteTable.frame = CGRect(x: self.frame.origin.x + 1, y: self.frame.origin.y - height, width: self.bounds.size.width - 2, height: height)
        } else { //appears from bottom of the field
            let height = min(availableHeight, CGFloat(self.tableView(self.autocompleteTable, numberOfRowsInSection: 0)) * self.autocompleteTable.rowHeight)
            self.autocompleteTable.frame = CGRect(x: self.frame.origin.x + 1, y: self.frame.origin.y + self.bounds.size.height, width: self.bounds.size.width - 2, height: height)
        }
    }

    override func editingDone() {
        self.autocompleteTable.removeFromSuperview()
        super.editingDone()
    }

    private func setBottomOffset(keyboardInfo: UIKeyboardInfo) {
        let offset = keyboardInfo.frame.size.height

        if self.keyboardHeight != offset {
            self.keyboardHeight = offset
            self.layoutAutocompleteTable()
        }
    }
}
