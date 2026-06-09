//
//  LogUtils.swift
//  CatVPN
//
//  Console filters:
//    [CV]         — all app logs
//    [CV][Go]     — cold start / splash / boot config
//    [CV][Link]   — tap connect → UI result
//    [CV][Ad]     — ads (any scene)
//    [CV][Tx]     — telemetry / report (any scene)
//

import Foundation

enum CVLogScene: String {
    case general
    case go = "Go"
    case link = "Link"
    case ad = "Ad"
    case tx = "Tx"
}

private let cvRoot = "[CV]"

private func cvEmit(scene: CVLogScene, warn: Bool, _ message: String) {
#if DEBUG
    let tag: String
    switch scene {
    case .general:
        tag = cvRoot
    case .go, .link, .ad, .tx:
        tag = "\(cvRoot)[\(scene.rawValue)]"
    }
    let mark = warn ? " !" : ""
    debugPrint("\(tag)\(mark) \(message)")
#endif
}

// MARK: - General

func cvLog(_ message: String) {
    cvEmit(scene: .general, warn: false, message)
}

func cvWarn(_ message: String) {
    cvEmit(scene: .general, warn: true, message)
}

// MARK: - Boot / startup

func goLog(_ message: String) {
    cvEmit(scene: .go, warn: false, message)
}

func goWarn(_ message: String) {
    cvEmit(scene: .go, warn: true, message)
}

// MARK: - Connect flow

func linkLog(_ message: String) {
    cvEmit(scene: .link, warn: false, message)
}

func linkWarn(_ message: String) {
    cvEmit(scene: .link, warn: true, message)
}

// MARK: - Ads

func adLog(_ message: String) {
    cvEmit(scene: .ad, warn: false, message)
}

// MARK: - Report / telemetry

func txLog(_ message: String) {
    cvEmit(scene: .tx, warn: false, message)
}

func txWarn(_ message: String) {
    cvEmit(scene: .tx, warn: true, message)
}

// MARK: - Shared layers (HTTP, crypto)

func cvLog(_ scene: CVLogScene, _ message: String) {
    cvEmit(scene: scene, warn: false, message)
}

func cvWarn(_ scene: CVLogScene, _ message: String) {
    cvEmit(scene: scene, warn: true, message)
}
