//
//  PoolTests.swift
//  ObservableTests
//
//  Created by Stanislav Lyubchenko on 31.05.2020.
//  Copyright © 2020 Stanislav Lyubchenko. All rights reserved.
//

import XCTest
@testable import Observable

final class PoolTests: XCTestCase {

	func testAppendingElementsWithoutPoolOversizing() {
		// arrange
		var pool = Pool<Int>(size: 5)

		// act
		(1...3).forEach { pool.append($0) }

		// assert
		XCTAssertEqual(pool.array, [1, 2, 3])
	}

	func testAppendingElementsWithPoolOversizing() {
		// arrange
		var pool = Pool<Int>(size: 3)

		// act
		(1...5).forEach { pool.append($0) }

		// assert
		XCTAssertEqual(pool.array, [3, 4, 5])
	}

	func testAppendingElementsInPoolWithZeroMaxSize() {
		// arrange
		var pool = Pool<Int>(size: 0)

		// act
		(1...5).forEach { pool.append($0) }

		// assert
		XCTAssertEqual(pool.array, [])
	}
}
