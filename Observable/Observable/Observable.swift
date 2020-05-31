//
//  Observable.swift
//  Cards
//
//  Created by Stanislav Lyubchenko on 08/10/2019.
//  Copyright © 2019 Sberbank. All rights reserved.
//

import Foundation

/// Интерфейс подписки
public protocol SubscriptionProtocol: AnyObject {
	/// Отписывает подписчика от текущей подписки
	func unsubscribe()
}

/// Подписчик
public protocol SubscriberProtocol: AnyObject {
	/// Список подписок, на которые подписывается подписчик
	var subscriptions: [SubscriptionProtocol] { get set }
}

private var subscriptionsStore = SubscriptionsStore()

// MARK: - Реализация по умолчанию для SubscriberProtocol
public extension SubscriberProtocol {
	var subscriptions: [SubscriptionProtocol] {
		get { subscriptionsStore[self] }
		set { subscriptionsStore[self] = newValue }
	}
}

/// Объект наблюдения за изменением значения Value
open class Observable<Value> {
	/// Нотификация, прилетающая при изменении значения Value у наблюдаемого объекта
	public struct Notification<Subscriber: SubscriberProtocol> {
		/// Подписчик
		public let subscriber: Subscriber

		/// Измененное значение
		public let value: Value

		/// Ссылка на подписку
		public fileprivate(set) weak var subscription: SubscriptionProtocol?

		/// Инициализатор
		/// - Parameters:
		///   - subscriber: подписчик
		///   - value: измененное значение
		///   - subscription: подписка
		public init(_ subscriber: Subscriber, _ value: Value, _ subscription: SubscriptionProtocol?) {
			self.subscriber = subscriber
			self.value = value
			self.subscription = subscription
		}
	}

	/// Сокращенная нотификация без подписчика, прилетающая при изменении значения Value у наблюдаемого объекта
	public struct ShortNotification {
		/// Измененное значение
		public let value: Value

		/// Ссылка на подписку
		public fileprivate(set) weak var subscription: SubscriptionProtocol?

		/// Инициализатор
		/// - Parameters:
		///   - value: измененное значение
		///   - subscription: подписка
		public init(_ value: Value, _ subscription: SubscriptionProtocol?) {
			self.value = value
			self.subscription = subscription
		}
	}

	/// Список подписок за изменением значения Value у объекта наблюдения
	fileprivate var subscriptions: [Weak<Subscription<Value>>] = []

	/// Пул для хранения опубликованных значений
	fileprivate var pullOfValues: Pool<Value>

	/// Подписчик, используемый для хранения подписок, созданных в рамках операторов
	fileprivate var subscriber = SubscriberObject()

	/// Завершено или нет наблюдение за новыми значениями Value
	fileprivate var isCompleted: Bool = false {
		didSet {
			onCompletion()
		}
	}

	/// Действие при завершении наблюдения
	fileprivate var onCompletion: () -> Void = {}

	/// Инициализатор
	///
	/// - Parameter maxPullOfValuesSize: максимальный размер пула хранения опубликованных значений
	public init(maxPullOfValuesSize: UInt = 0) {
		pullOfValues = Pool<Value>(size: maxPullOfValuesSize)
	}

	/// Инициализатор
	///
	/// - Parameter values: публикуемые значения
	public convenience init(values: Value...) {
		self.init(values: values)
	}

	/// Инициализатор
	///
	/// - Parameter values: публикуемые значения
	public convenience init(values: [Value]) {
		self.init(maxPullOfValuesSize: UInt(values.count))
		values.forEach { self.pullOfValues.append($0) }
	}

	deinit {
		subscriptions.forEach { $0.value?.unsubscribe() }
	}

	/// Подписывает наблюдателя на изменения значения Value у наблюдаемого объекта
	///
	/// - Parameters:
	///   - subscriber: подписчик
	///   - handler: обработчик изменения значения Value с нотификацией
	/// - Returns: подписка
	@discardableResult
	public func subscribe<Subscriber>(_ subscriber: Subscriber,
									  _ handler: @escaping (Notification<Subscriber>) -> Void) -> SubscriptionProtocol
		where Subscriber: SubscriberProtocol {
			removeInactiveSubscriptions()
			let subscriptionWrapper = SubscriptionWrapper()
			defer {
				pullOfValues.array.forEach { handler(.init(subscriber, $0, subscriptionWrapper)) }
				if isCompleted { onCompletion() }
			}
			guard !isCompleted else { return subscriptionWrapper }
			let sHandler: (Value) -> Void = { [weak subscriber, weak self] value in
				guard let subscriber = subscriber, let self = self else { return }
				handler(.init(subscriber, value, subscriptionWrapper))
				if self.isCompleted {
					subscriptionWrapper.unsubscribe()
				}
			}
			let subscription = Subscription(sHandler)
			subscription.subscriber = subscriber
			subscriptionWrapper.wrappedSubscription = subscription
			subscriptions.append(Weak(subscription))
			return subscription
	}

	/// Подписывает на изменение значения Value у наблюдаемого объекта
	/// - Parameter handler: обработчик изменения значения Value с нотификацией
	/// - Returns: подписка
	@discardableResult
	public func subscribe(handler: @escaping (ShortNotification) -> Void) -> SubscriptionProtocol {
		subscribe(subscriber) { handler(.init($0.value, $0.subscription)) }
	}

	/// Отписать наблюдателя от всех подписок связанных с объектом наблюдения
	/// - Parameter subscriber: наблюдатель
	public func unsubscribe<Subscriber>(_ subscriber: Subscriber) where Subscriber: SubscriberProtocol {
		subscriptions.filter { $0.value?.subscriber === subscriber }.forEach { $0.value?.unsubscribe() }
		removeInactiveSubscriptions()
	}

	/// Отписать наблюдателя от всех подписок
	/// - Parameter subscriber: наблюдатель
	/// - Returns: удаленные подписки
	public func unsubscribeAll() {
		subscriptions.compactMap { $0.value }.forEach { $0.unsubscribe() }
		self.subscriptions.removeAll()
	}

	fileprivate func removeInactiveSubscriptions() {
		subscriptions.removeAll { subscriptionWrapper in
			guard let subscription = subscriptionWrapper.value, let subscriber = subscription.subscriber else {
				return true
			}
			return !subscriber.subscriptions.contains { subscription === $0 }
		}
	}
}

// MARK: - Операторы
public extension Observable {
	/// Возвращает новый наблюдаемый объект за изменением значения NewValue, преобразуя значение Value в NewValue
	///
	/// - Parameter transform: преобразует значение Value в NewValue
	/// - Returns: объект наблюдения за преобразованным значением
	func map<NewValue>(_ transform: @escaping (Value) -> NewValue) -> Observable<NewValue> {
		let newObservable = Observable<NewValue>(maxPullOfValuesSize: pullOfValues.maxSize)
		let publisher = Publisher<NewValue>(observable: newObservable)
		subscribe(subscriber) { publisher.publish(transform($0.value)) }
		return newObservable
	}

	/// Возвращает новый наблюдаемый объект за изменением значения NewValue, проектируя каждое изменение значения
	/// Value текущего объекта наблюдения в объект наблюдения за изменением значения NewValue с помощью
	/// предоставленного преобразования, и объединяет наблюдения за измененением значения NewValue у тех объектов в
	/// наблюдение за единственным возвращаемым объектом
	///
	/// - Parameter transform: преобразование значения Value в наблюдаемый объект за изменением значения NewValue
	/// - Returns: объект наблюдения за изменением значения NewValue
	func flatMap<NewValue>(_ transform: @escaping (Value) -> Observable<NewValue>) -> Observable<NewValue> {
		let newObservable = Observable<NewValue>(maxPullOfValuesSize: pullOfValues.maxSize)
		let publisher = Publisher<NewValue>(observable: newObservable)
		subscribe(subscriber) {
			let observable = transform($0.value)
			observable.subscribe(observable.subscriber) { publisher.publish($0.value) }
		}
		return newObservable
	}

	/// Возвращает наблюдаемый объект за изменением значения Value, который предоставляет ограниченное количество
	/// изменений значения Value от исходного объекта наблюдения и прекращает уведомлять после получения последнего
	/// значения
	///
	/// - Parameter number: число изменений значения Value, которые может получить наблюдаемый объект от исходного
	/// объекта наблюдения
	/// - Returns: объект наблюдения за изменением значения Value
	func take(_ number: UInt) -> Observable<Value> {
		let maxPullOfValuesSize = min(number, pullOfValues.maxSize)
		let newObservable = Observable<Value>(maxPullOfValuesSize: maxPullOfValuesSize)

		var attempts = number
		subscribe { notification in
			if attempts > 0 {
				Publisher(observable: newObservable).publish(notification.value)
				attempts -= 1
			}

			if attempts == 0 {
				newObservable.isCompleted = true
				notification.subscription?.unsubscribe()
			}
		}

		return newObservable
	}
}

/// Объект, публикующий новое значение Value для наблюдаемого объекта и уведомляющих его наблюдателей
open class Publisher<Value> {
	/// Режим оповещения
	public enum NotifiableMode {
		/// Все подписки
		case all
		/// Только первая подписка используется для оповещения
		case first
		/// Ниодна подписка не используется для оповещения
		case noOne
	}
	/// Объект наблюдения за изменением значения Value
	public let observable: Observable<Value>

	/// Создает Publisher и связывает его с объектом наблюдения за изменением значения Value
	///
	/// - Parameter observable: объект наблюдения за изменением значения Value
	public init(observable: Observable<Value> = Observable<Value>()) {
		self.observable = observable
	}

	/// Публикует новое значение Value для наблюдаемого объекта и оповещает об этом его наблюдателей, подписанных
	/// на это изменение
	///
	/// - Parameter value: новое значение Value для наблюдаемого объекта
	/// - Parameter notifiableMode: режим оповещения
	public func publish(_ value: Value, notifiableMode: NotifiableMode = .all) {
		guard !observable.isCompleted else { observable.unsubscribeAll(); return }
		observable.pullOfValues.append(value)
		observable.removeInactiveSubscriptions()
		switch notifiableMode {
		case .all:
			observable.subscriptions.forEach { $0.value?.handler(value) }
		case .first:
			observable.subscriptions.first?.value?.handler(value)
		case .noOne: break
		}
	}

	/// Публикует последнее значение Value для наблюдаемого объекта, если он еще может принять это значение, и оповещает
	/// об этом его наблюдателей, подписанных на это изменение. После этого объект наблюдения больше не сможет
	/// принять новые значения Value и соотвественно оповестить об этом своих наблюдателей
	/// - Parameter value: последнее значение Value для наблюдаемого объекта
	/// - Parameter notifiableMode: режим оповещения
	public func publishLast(_ value: Value, notifiableMode: NotifiableMode = .all) {
		publish(value, notifiableMode: notifiableMode)
		observable.isCompleted = true
	}
}

/// Подписка на изменение значения
private class Subscription<Value>: SubscriptionProtocol {
	let handler: (Value) -> Void
	weak var subscriber: SubscriberProtocol? {
		didSet {
			subscriber?.subscriptions.append(self)
		}
	}

	init(_ handler: @escaping (Value) -> Void) {
		self.handler = handler
	}

	func unsubscribe() {
		subscriber?.subscriptions.removeAll { $0 === self }
	}
}

private class SubscriptionWrapper: SubscriptionProtocol {
	weak var wrappedSubscription: SubscriptionProtocol?
	func unsubscribe() {
		wrappedSubscription?.unsubscribe()
	}
}

/// Подписчик, используемый для внутренних целей
private class SubscriberObject: SubscriberProtocol {
	var subscriptions: [SubscriptionProtocol] = []
}

private struct SubscriptionsStore {
	private struct SubscriberWrapper {
		weak var subscriber: SubscriberProtocol?
	}
	private var store: [ObjectIdentifier: (SubscriberWrapper, [SubscriptionProtocol])] = [:]

	subscript(subscriber: SubscriberProtocol) -> [SubscriptionProtocol] {
		mutating get {
			compact()
			return store[ObjectIdentifier(subscriber)]?.1 ?? []
		}
		set(subscriptions) {
			compact()
			store[ObjectIdentifier(subscriber)] = (SubscriberWrapper(subscriber: subscriber), subscriptions)
		}
	}

	private mutating func compact() {
		store = store.filter { _, value in value.0.subscriber != nil }
	}
}

// MARK: - Расширение для Publisher, который делает публикации без конкретных значений
public extension Publisher where Value == Void {
	/// Инициализатор паблишера без конкретных значений
	convenience init() {
		self.init(observable: .empty)
	}

	/// Осуществляет публикацию. Значение при этом не используется, т.к. Value == Void
	/// - Parameter notifiableMode: режим оповещения
	func publish(notifiableMode: NotifiableMode = .all) {
		publish((), notifiableMode: notifiableMode)
	}

	/// Осуществляет последнюю публикацию без значения. После этого подписчики больше не будут уведомлены о новых
	/// публикациях
	/// - Parameter notifiableMode: режим оповещения
	func publishLast(notifiableMode: NotifiableMode = .all) {
		publishLast((), notifiableMode: notifiableMode)
	}
}

// MARK: - Расширение для объекта наблюдения без значений
public extension Observable where Value == Void {
	/// Возвращает объект наблюдения за пустыми значениями
	static var empty: Observable<Value> { Observable() }

	/// Возвращает объект наблюдения за пустыми значениями хранящий последнюю публикацию известную при создании
	static func oneEmpty() -> Observable<Value> { Observable(values: ()) }

	/// Подписывает за изменениями объекта наблюдения без значений
	/// - Parameter handler: обработчик изменения значения Value с нотификацией
	/// - Returns: подписка
	@discardableResult
	func subscribe(handler: @escaping () -> Void) -> SubscriptionProtocol {
		subscribe { _ in handler() }
	}
}
