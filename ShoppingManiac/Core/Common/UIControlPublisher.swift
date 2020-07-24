//
//  UIControlPublisher.swift
//  ShoppingManiac
//
//  Created by Dmitry Matyushkin on 7/24/20.
//  Copyright © 2020 Dmitry Matyushkin. All rights reserved.
//

import Combine
import UIKit

struct UIControlPublisher<Control: UIControl>: Publisher {

	final class UIControlSubscription<SubscriberType: Subscriber, Control: UIControl>: Subscription where SubscriberType.Input == Control {
		private var subscriber: SubscriberType?
		private let control: Control

		init(subscriber: SubscriberType, control: Control, event: UIControl.Event) {
			self.subscriber = subscriber
			self.control = control
			control.addTarget(self, action: #selector(eventHandler), for: event)
		}

		func request(_ demand: Subscribers.Demand) {
		}

		func cancel() {
			subscriber = nil
		}

		@objc private func eventHandler() {
			_ = subscriber?.receive(control)
		}
	}

	typealias Output = Control
	typealias Failure = Never

	let control: Control
	let controlEvents: UIControl.Event

	init(control: Control, events: UIControl.Event) {
		self.control = control
		self.controlEvents = events
	}

	func receive<S>(subscriber: S) where S: Subscriber, S.Failure == UIControlPublisher.Failure, S.Input == UIControlPublisher.Output {
		let subscription = UIControlSubscription(subscriber: subscriber, control: control, event: controlEvents)
		subscriber.receive(subscription: subscription)
	}
}
