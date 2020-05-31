//
//  Pool.swift
//  Cards
//
//  Created by Stanislav Lyubchenko on 23.10.2019.
//  Copyright © 2019 Sberbank. All rights reserved.
//

import Foundation

/// Пул элементов с ограничением по количеству элементов
struct Pool<Element> {
	private(set) var array: [Element] = []
	/// Максимальный размер пула
	let maxSize: UInt

	/// Инициализатор
	///
	/// - Parameter size: максимальный размер пула
	init(size: UInt) {
		self.maxSize = size
	}

	/// Добавление нового элемента в пул. Если размер пула превышен, то при добавлении нового элемента самый первый
	/// элемент удаляется из пула
	///
	/// - Parameter element: добавляемый элемент
	mutating func append(_ element: Element) {
		guard maxSize != 0 else { return }
		if array.count >= maxSize {
			array.removeFirst()
		}
		array.append(element)
	}
}
