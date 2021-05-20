//
//  AutocompleteTextField.swift
//  ShoppingManiac
//
//  Created by Dmitry Matyushkin on 28/05/2017.
//  Copyright © 2017 Dmitry Matyushkin. All rights reserved.
//

import UIKit
import Combine

class AutocompleteTextField: RoundRectTextField, UITableViewDelegate, UITableViewDataSource {

    private let autocompleteTable = UITableView()
    private var cancellables = Set<AnyCancellable>()

    var autocompleteStrings: [String] = [] {
        didSet {
            self.lowercasedStrings = autocompleteStrings.map({ $0.lowercased() })
        }
    }
    private var lowercasedStrings: [String] = []

    private var keyboardHeight: CGFloat = 0

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
		LocalNotifications.keyboardWillChangeFrame.listen().sink(receiveCompletion: {_ in }, receiveValue: {[weak self] value in
			self?.setBottomOffset(keyboardInfo: value)
		}).store(in: &cancellables)
		LocalNotifications.keyboardWillHide.listen().map({_ in UIKeyboardInfo(info: [:])}).sink(receiveCompletion: {_ in }, receiveValue: {[weak self] value in
			self?.setBottomOffset(keyboardInfo: value)
		}).store(in: &cancellables)
    }

    private func item(forIndexPath indexPath: IndexPath) -> String {
        let idx = self.lowercasedStrings.enumerated().filter({ (_, value) in value.contains(self.text?.lowercased() ?? "") })[indexPath.row].offset
        return self.autocompleteStrings[idx]
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return self.lowercasedStrings.filter({ $0.contains(self.text?.lowercased() ?? "") }).count
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
        let text = self.item(forIndexPath: indexPath)
        self.text = text
        self.sendActions(for: .editingChanged)
        self.autocompleteTable.removeFromSuperview()
    }

    override func editingChanged() {
        super.editingChanged()
        if self.autocompleteTable.superview == nil {
            self.superview?.addSubview(self.autocompleteTable)
            self.superview?.bringSubviewToFront(self.autocompleteTable)
        }
        self.layoutAutocompleteTable()
        self.autocompleteTable.reloadData()
    }

    private func layoutAutocompleteTable() {
        let frame = self.frame
        let screenHeight = UIScreen.main.bounds.height
        let availableHeight = screenHeight - self.keyboardHeight - self.frame.origin.y - self.frame.size.height
        if frame.origin.y > (availableHeight - frame.origin.y - frame.size.height) { // appears from top of the field
            let height = min(frame.origin.y, CGFloat(self.tableView(self.autocompleteTable, numberOfRowsInSection: 0)) * self.autocompleteTable.rowHeight)
            self.autocompleteTable.frame = CGRect(x: self.frame.origin.x + 1, y: self.frame.origin.y - height, width: self.bounds.size.width - 2, height: height)
        } else { // appears from bottom of the field
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
