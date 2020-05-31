//
//  Weak.swift
//  Cards
//
//  Created by Stanislav Lyubchenko on 09/08/2019.
//  Copyright © 2019 SberTech. All rights reserved.
//

import Foundation

/// Контейнер объекта со слабой ссылкой на него. Полезно использовать там, где нельзя объявить слабую ссылку на объект,
/// например, в ассоциативном типе перечисления.
struct Weak<T> where T: AnyObject {
	/// Слабая ссылка на объект, которую хранит контейнер
	private(set) weak var value: T?

	/// Инициализатор
	///
	/// - Parameter value: Объект, слабую ссылку на который необходимо хранить в контейнере
	init(_ value: T) {
		self.value = value
	}
}
