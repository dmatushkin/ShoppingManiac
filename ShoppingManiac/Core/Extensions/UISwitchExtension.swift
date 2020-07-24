//
//  UISwitchExtension.swift
//  ShoppingManiac
//
//  Created by Dmitry Matyushkin on 7/24/20.
//  Copyright © 2020 Dmitry Matyushkin. All rights reserved.
//

import UIKit
import Combine

extension UISwitch {

	func publisher(for events: UIControl.Event) -> AnyPublisher<UISwitch, Never> {
		return UIControlPublisher(control: self, events: events).eraseToAnyPublisher()
    }

	func bind(to variable: CurrentValueSubject<Bool, Never>, store: inout Set<AnyCancellable>) {
		self.isOn = variable.value
		variable.sink(receiveCompletion: {_ in }, receiveValue: {[weak self] value in
			if self?.isOn != value {
				self?.isOn = value
			}
		}).store(in: &store)
		self.publisher(for: .valueChanged).sink(receiveCompletion: {_ in }, receiveValue: { item in
			if variable.value != item.isOn {
				variable.send(item.isOn)
			}
		}).store(in: &store)
    }
}
