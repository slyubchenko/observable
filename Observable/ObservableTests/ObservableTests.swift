//
//  ObservableTests.swift
//  ObservableTests
//
//  Created by Stanislav Lyubchenko on 31.05.2020.
//  Copyright © 2020 Stanislav Lyubchenko. All rights reserved.
//

import XCTest
@testable import Observable

final class ObservableTests: XCTestCase {

	final class Subscriber: SubscriberProtocol {
		var subscriptions: [SubscriptionProtocol] = []
	}

	var subscriber: Subscriber!

	override func setUp() {
		super.setUp()
		subscriber = Subscriber()
	}

	override func tearDown() {
		subscriber = nil
		super.tearDown()
	}

	func testSubscribtions() {
		// arrange
		let publisher = Publisher<Int>()
		let observable = publisher.observable
		var values: [Int] = []
		observable.subscribe(subscriber) { values.append($0.value) }
		observable.subscribe { values.append($0.value) }

		// act
		publisher.publish(5)

		// assert
		XCTAssertEqual(values, [5, 5])
		XCTAssertEqual(subscriber.subscriptions.count, 1)
    }

	func testPublishWithNotificationsForFirstSubscription() {
		// arrange
		var value1: Int?
		var value2: Int?
		let observable = Observable<Int>()
		observable.subscribe { value1 = $0.value }
		observable.subscribe { value2 = $0.value }

		// act
		Publisher(observable: observable).publish(1, notifiableMode: .first)

		//assert
		XCTAssertNil(value2)
		XCTAssertEqual(value1, 1)
	}

	func testPublishWithoutNotifications() {
		// arrange
		var state = false
		let observable = Observable.empty
		observable.subscribe {
			state = true
		}
		observable.subscribe {
			state = true
		}

		// act
		Publisher(observable: observable).publish(notifiableMode: .noOne)

		//assert
		XCTAssertFalse(state)
	}

	func testMap() {
		// arrange
		let publisher = Publisher<String>()
		let stringObservable = publisher.observable
		let intObservable = stringObservable.map { Int($0) ?? 0 }
		var stringValue: String?
		var intValue: Int?

		// act
		stringObservable.subscribe(subscriber) { stringValue = $0.value }
		intObservable.subscribe(subscriber) { intValue = $0.value }
		publisher.publish("123")

		// assert
		XCTAssertEqual(stringValue!, "123")
		XCTAssertEqual(intValue!, 123)
		XCTAssertEqual(subscriber.subscriptions.count, 2)
	}

	func testFlatMap() {
		// arrange
		let boolPublisher = Publisher<Bool>()
		let stringPublisher1 = Publisher<String>()
		let stringPublisher2 = Publisher<String>()
		let boolObservable = boolPublisher.observable
		let stringObservable: Observable<String> = boolObservable.flatMap { boolValue in
			if boolValue {
				return stringPublisher1.observable
			} else {
				return stringPublisher2.observable
			}
		}
		var boolValues: [Bool] = []
		var stringValues: [String] = []

		// act
		boolObservable.subscribe(subscriber) { boolValues.append($0.value) }
		stringObservable.subscribe(subscriber) { stringValues.append($0.value) }
		stringPublisher1.publish("test 1")
		stringPublisher2.publish("test 2")
		boolPublisher.publish(true)
		stringPublisher1.publish("test 3")
		stringPublisher2.publish("test 4")
		boolPublisher.publish(false)
		stringPublisher1.publish("test 5")
		stringPublisher2.publish("test 6")
		boolPublisher.publish(true)
		stringPublisher1.publish("test 7")
		stringPublisher2.publish("test 8")

		// assert
		XCTAssertEqual(boolValues, [true, false, true])
		XCTAssertEqual(stringValues, ["test 3", "test 5", "test 6", "test 7", "test 7", "test 8"])
		XCTAssertEqual(subscriber.subscriptions.count, 2)
	}

	func testFlatMap2() {
		// arrange
		let boolPublisher = Publisher<Bool>()
		let stringObservable: Observable<String> = boolPublisher.observable.flatMap { boolValue in
			return boolValue ? Observable<String>(values: "👍") : Observable<String>()
		}
		var values: [String] = []

		// act
		stringObservable.subscribe(subscriber) { values.append($0.value) }
		boolPublisher.publish(true)
		boolPublisher.publish(false)
		boolPublisher.publish(true)

		// assert
		XCTAssertEqual(values, ["👍", "👍"])
		XCTAssertEqual(subscriber.subscriptions.count, 1)
	}

	func testTakeWithMaxPoolSizeEqualZeroAndNumberEqualZero() {
		// arrange
		let sourceObservable = Observable<Int>()
		var values: [Int] = []

		// act
		Publisher(observable: sourceObservable).publish(1)
		let targetObservable = sourceObservable.take(0)
		targetObservable.subscribe { values.append($0.value) }
		Publisher(observable: sourceObservable).publish(2)
		Publisher(observable: targetObservable).publish(3)

		//assert
		XCTAssertTrue(values.isEmpty)
	}

	func testTakeWithMaxPoolSizeMoreThanZeroAndNumberEqualZero() {
		// arrange
		let sourceObservable = Observable<Int>(maxPullOfValuesSize: 1)
		var values: [Int] = []

		// act
		Publisher(observable: sourceObservable).publish(1)
		let targetObservable = sourceObservable.take(0)
		targetObservable.subscribe { values.append($0.value) }
		Publisher(observable: sourceObservable).publish(2)
		Publisher(observable: targetObservable).publish(3)

		//assert
		XCTAssertTrue(values.isEmpty)
	}

	func testTakeWithMaxPoolSizeEqualZeroAndNumberMoreThanZero() {
		// arrange
		let sourceObservable = Observable<Int>()
		var values: [Int] = []

		// act
		Publisher(observable: sourceObservable).publish(1)
		let targetObservable = sourceObservable.take(1)
		targetObservable.subscribe { values.append($0.value) }
		Publisher(observable: sourceObservable).publish(2)
		Publisher(observable: targetObservable).publish(3)

		//assert
		XCTAssertEqual(values, [2])
	}

	func testTakeWithMaxPoolSizeMoreThanZeroAndLessThanNumber() {
		// arrange
		let sourceObservable = Observable<Int>(maxPullOfValuesSize: 1)
		var values: [Int] = []

		// act
		Publisher(observable: sourceObservable).publish(1)
		let targetObservable = sourceObservable.take(2)
		targetObservable.subscribe { values.append($0.value) }
		Publisher(observable: sourceObservable).publish(2)
		Publisher(observable: targetObservable).publish(3)
		Publisher(observable: sourceObservable).publish(4)

		//assert
		XCTAssertEqual(values, [1, 2])
	}

	func testTakeWithMaxPoolSizeMoreThanNumberAndNumberMoreThenZero() {
		// arrange
		let sourceObservable = Observable<Int>(maxPullOfValuesSize: 2)
		var values: [Int] = []

		// act
		Publisher(observable: sourceObservable).publish(1)
		Publisher(observable: sourceObservable).publish(2)
		let targetObservable = sourceObservable.take(1)
		targetObservable.subscribe { values.append($0.value) }
		Publisher(observable: sourceObservable).publish(3)
		Publisher(observable: targetObservable).publish(4)

		//assert
		XCTAssertEqual(values, [1])
	}

	func testMindfulObservableSubscription() {
		// arrange
		let publisher = Publisher<Int>(observable: Observable<Int>(maxPullOfValuesSize: 1))
		var valuesOfSubscription1: [Int] = []
		var valuesOfSubscription2: [Int] = []
		var valuesOfSubscription3: [Int] = []

		// act
		publisher.observable.subscribe(subscriber) {
			valuesOfSubscription1.append($0.value)
		}
		publisher.publish(1)
		publisher.observable.subscribe(subscriber) {
			valuesOfSubscription2.append($0.value)
		}
		publisher.publish(2)
		publisher.observable.subscribe(subscriber) {
			valuesOfSubscription3.append($0.value)
		}

		// assert
		XCTAssertEqual(valuesOfSubscription1, [1, 2])
		XCTAssertEqual(valuesOfSubscription2, [1, 2])
		XCTAssertEqual(valuesOfSubscription3, [2])
		XCTAssertEqual(subscriber.subscriptions.count, 3)
	}

	func testCreateObservableWithPublishedValues() {
		// arrange
		let observable = Observable<Int>(values: 1, 2, 3)
		var values: [Int] = []

		// act
		observable.subscribe(subscriber) { values.append($0.value) }

		// assert
		XCTAssertEqual(values, [1, 2, 3])
		XCTAssertEqual(subscriber.subscriptions.count, 1)
	}

	func testUnsubscribingFromConcreteSubscriptions() {
		// arrange
		let publisher = Publisher<Int>()
		var valueOfSubscription1: Int?
		var valueOfSubscription2: Int?
		var valueOfSubscription3: Int?
		var valueOfSubscription4: Int?
		weak var subscription1: SubscriptionProtocol? = publisher.observable.subscribe(subscriber) {
			valueOfSubscription1 = $0.value
			$0.subscription?.unsubscribe()
		}
		weak var subscription2: SubscriptionProtocol? = publisher.observable.subscribe(subscriber) {
			valueOfSubscription2 = $0.value
		}
		weak var subscription3: SubscriptionProtocol? = publisher.observable.subscribe(subscriber) {
			valueOfSubscription3 = $0.value
		}
		let subscription4 = publisher.observable.subscribe(subscriber) { [weak publisher] in
			valueOfSubscription4 = $0.value
			$0.subscription?.unsubscribe()
			publisher?.publish($0.value + 3)
		}

		// act
		publisher.publish(0)
		publisher.publish(1)
		subscription2?.unsubscribe()
		publisher.publish(2)
		subscription4.unsubscribe()

		//assert
		XCTAssertEqual(valueOfSubscription1, 0)
		XCTAssertNil(subscription1)
		XCTAssertEqual(valueOfSubscription2, 1)
		XCTAssertNil(subscription2)
		XCTAssertEqual(valueOfSubscription3, 2)
		XCTAssertNotNil(subscription3)
		XCTAssertEqual(valueOfSubscription4, 0)
		XCTAssertEqual(subscriber.subscriptions.count, 1)
	}

	func testUnsubscribingFromObservable() {
		// arrange
		let subscriber1 = Subscriber()
		let subscriber2 = Subscriber()
		let publisher = Publisher<Int>()
		var result = 0
		publisher.observable.subscribe(subscriber1) { _ in result += 1 }
		publisher.observable.subscribe(subscriber2) { _ in result += 1 }
		publisher.observable.subscribe(subscriber1) { _ in result += 1 }
		publisher.publish(1)
		publisher.observable.unsubscribe(subscriber1)

		// act
		publisher.publish(2)

		//assert
		XCTAssertEqual(result, 4)
	}

	func testSubscriptionsIfObservableDealocated() {
		// arrange
		var observable: Observable<Int>? = Observable()
		observable?.subscribe(subscriber) { _ in }
		observable?.subscribe(subscriber) { _ in }
		observable?.subscribe { _ in }
		weak var weakObservable = observable

		// act
		observable = nil

		//assert
		XCTAssertTrue(subscriber.subscriptions.isEmpty)
		XCTAssertNil(weakObservable)
	}

	func testUnsubscribeFromAllSubscriptions() {
		// arrange
		let publisher = Publisher()
		var couner = 0
		publisher.observable.subscribe(subscriber) { _ in couner += 1 }
		publisher.observable.subscribe(subscriber) { _ in couner += 1 }

		// act
		publisher.publish()
		publisher.observable.unsubscribeAll()
		publisher.publish()

		//assert
		XCTAssertEqual(subscriber.subscriptions.count, 0)
		XCTAssertEqual(couner, 2)
	}

	func testCompletedObservable() {
		// arrange
		let publisher = Publisher<Int>()
		var values = [Int]()
		publisher.observable.subscribe(subscriber) { values.append($0.value) }

		// act
		publisher.publish(0)
		publisher.publishLast(1)
		publisher.publish(2)
		publisher.publishLast(3)

		//assert
		XCTAssertEqual(values, [0, 1])
		XCTAssertEqual(subscriber.subscriptions.count, 0)
	}
}
