//
//  AdBootstrap.swift
//  CatVPN
//

import Foundation

/// First install: unlock after ATT to init ad/analytics SDKs and preload inventory. Ad list APIs still run on cold start.
enum AdBootstrap {

    private static let attFlowKey = "hasCompletedATTFlow"
    private static let migrationKey = "hasMigratedATTGate"
    private static var sdkActivator: (() -> Void)?

    static var isAdStackUnlocked: Bool {
        UserDefaults.standard.bool(forKey: attFlowKey)
    }

    static func registerSDKActivator(_ activator: @escaping () -> Void) {
        sdkActivator = activator
        if isAdStackUnlocked {
            sdkActivator?()
        }
    }

    /// One-time upgrade path: users who already agreed privacy before this gate existed.
    static func migrateLegacyUserIfNeeded() {
        let defaults = UserDefaults.standard
        guard !defaults.bool(forKey: migrationKey) else { return }
        if defaults.bool(forKey: "hasSeenPrivacyPopup") {
            defaults.set(true, forKey: attFlowKey)
            cvLog("att gate legacy migrate")
        }
        defaults.set(true, forKey: migrationKey)
    }

    static func unlockAdStack() {
        UserDefaults.standard.set(true, forKey: attFlowKey)
        cvLog("att gate unlocked")
        sdkActivator?()
    }
}
