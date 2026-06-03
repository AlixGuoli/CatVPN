//
//  LogUtils.swift
//  CatVPN
//
//  Created by Stephen Schaaf on 2025/7/24.
//
import Foundation

func logDebug(_ items: Any..., prefix: String = "[🐱 CatCat **]", separator: String = " ", terminator: String = "\n") {
#if DEBUG
    let message = items.map { "\($0)" }.joined(separator: separator)
    debugPrint("\(prefix) \(message)", terminator: terminator)
#endif
}

func logPrint(_ items: Any..., prefix: String = "[🐱 CatCat **]", separator: String = " ", terminator: String = "\n") {
#if DEBUG
    let message = items.map { "\($0)" }.joined(separator: separator)
    print("\(prefix) \(message)", terminator: terminator)
#endif
}
