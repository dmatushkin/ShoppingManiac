//
//  UIButtonExtension.swift
//  ShoppingManiac
//
//  Created by Dmitry Matyushkin on 12/05/2018.
//  Copyright © 2018 Dmitry Matyushkin. All rights reserved.
//

import UIKit
import Combine

extension UIButton {

	func publisher(for events: UIControl.Event) -> AnyPublisher<UIButton, Never> {
		return UIControlPublisher(control: self, events: events).eraseToAnyPublisher()
    }
    
	func tagRatingBinding(variable: CurrentValueSubject<Int, Never>, store: inout Set<AnyCancellable>) {
		self.isSelected = (self.tag <= variable.value)
		variable.sink(receiveCompletion: {_ in }, receiveValue: {[weak self] value in
			guard let self = self else { return }
			self.isSelected = (self.tag <= value)
		}).store(in: &store)
		self.publisher(for: .touchUpInside).sink(receiveCompletion: {_ in }, receiveValue: { button in
			variable.send(button.tag)
		}).store(in: &store)
    }
}
