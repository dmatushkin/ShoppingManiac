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

	func publisher(for events: UIControl.Event) -> AnyPublisher<UITextField, Never> {
		return UIControlPublisher(control: self, events: events).eraseToAnyPublisher()
    }

	func bind(to subject: CurrentValueSubject<String?, Never>, store: inout Set<AnyCancellable>) {
		self.text = subject.value
		self.publisher(for: .editingChanged).sink(receiveCompletion: {_ in }, receiveValue: {field in
			if field.text != subject.value {
				subject.send(field.text)
			}
		}).store(in: &store)
		subject.sink(receiveCompletion: {_ in }, receiveValue: { value in
			if value != self.text {
				self.text = value
			}
		}).store(in: &store)
	}
}
