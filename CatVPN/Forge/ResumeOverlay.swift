//
//  ResumeOverlay.swift
//  CatVPN
//

import Foundation

enum ResumeOverlay {

    enum Action {
        case none
        case showWarmSplash
    }

    static func didBecomeActive(
        wasInBackground: Bool,
        isAppStarted: Bool,
        showSplashOnForeground: Bool,
        vm: MainViewmodel
    ) -> Action {
        goLog("resume started=\(isAppStarted) bg=\(wasInBackground) splash=\(showSplashOnForeground)")

        guard wasInBackground, !isAppStarted else { return .none }

        let forge = ForgeHub.shared
        if vm.isBaseConfigReady, VaultRegistry.shared.isForgeEnabled() {
            forge.warmInventory(tag: "foreground")
        }
        vm.checkAndUpdateConfigsIfNeeded()

        guard vm.isPrivacyAgreed else {
            adLog("splash skip privacy")
            return .none
        }

        if vm.showConnecting || vm.connectionStatus == .connecting {
            adLog("splash skip vpn connecting page=\(vm.showConnecting)")
            return .none
        }

        if forge.isPresenting {
            adLog("splash skip already showing")
            return .none
        }

        if forge.hasInventory() {
            goLog("splash warm show")
            return .showWarmSplash
        }

        adLog("splash skip no inventory")
        return .none
    }
}
