//
//  UITextFieldExtension.swift
//  ShoppingManiac
//
//  Created by Dmitry Matyushkin on 7/23/20.
//  Copyright © 2020 Dmitry Matyushkin. All rights reserved.
//

import UIKit
import Combine

extension UITextField {

	var textPublisher: AnyPublisher<String?, Never> {
		return NotificationCenter.default.publisher(for: UITextField.textDidChangeNotification, object: self)
			.compactMap({ $0.object as? UITextField })
			.map({ $0.text })
			.eraseToAnyPublisher()
	}

	func bind(to subject: CurrentValueSubject<String?, Never>, store: inout Set<AnyCancellable>) {
		self.text = subject.value
		self.textPublisher.sink(receiveCompletion: {_ in }, receiveValue: { value in
			if value != subject.value {
				subject.send(value)
			}
		}).store(in: &store)
		subject.sink(receiveCompletion: {_ in }, receiveValue: { value in
			if value != self.text {
				self.text = value
			}
		}).store(in: &store)
	}
}
