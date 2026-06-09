//
//  ForgeHub.swift
//  CatVPN
//

import Foundation
import UIKit

class ForgeHub {

    static var shared = ForgeHub()

    private let registry = VaultRegistry.shared

    private init() {}

    var isPresenting: Bool {
        get { registry.isPresenting }
        set { registry.isPresenting = newValue }
    }

    var isVip: Bool {
        get { registry.isVip }
        set { registry.isVip = newValue }
    }

    var isMediationMode: Bool { registry.isMediationMode }

    func hasInventory() -> Bool {
        registry.hasInventory()
    }

    func warmInventory(tag: String? = nil) {
        registry.warmInventory(tag: tag)
    }

    func warmInventory(onReady: (() -> Void)? = nil, onFailed: (() -> Void)? = nil) {
        registry.warmInventory(onReady: onReady, onFailed: onFailed)
    }

    func presentFullscreen(onClose: (() -> Void)? = nil) {
        guard let rootVC = rootViewController() else { return }
        registry.presentFullscreen(from: rootVC, onClose: onClose)
    }

    private func rootViewController() -> UIViewController? {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first(where: { $0.isKeyWindow })?.rootViewController
    }
}
