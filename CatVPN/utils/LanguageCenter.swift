//
//  LocalizationManager.swift
//  CatVPN
//
//  Created by Stephen Schaaf on 2025/8/14.
//

import Foundation
import SwiftUI

class LanguageCenter: ObservableObject {
    static let shared = LanguageCenter()
    
    @Published var currentLanguage: String = ""
    private let supportedLanguages = ["en", "ru", "de", "fr"]
    
    private init() {
        loadSavedLanguage()
    }
    
    private func loadSavedLanguage() {
        let savedLanguage = UserDefaults.standard.string(forKey: "AppLanguage")
        if let saved = savedLanguage, supportedLanguages.contains(saved) {
            currentLanguage = saved
        } else {
            let systemLanguage = Locale.current.language.languageCode?.identifier ?? "en"
            currentLanguage = supportedLanguages.contains(systemLanguage) ? systemLanguage : "en"
        }
        Bundle.updateLanguage(currentLanguage)
    }
    
    func updateLanguage(_ languageCode: String) {
        guard supportedLanguages.contains(languageCode) else { return }
        
        currentLanguage = languageCode
        Bundle.updateLanguage(languageCode)
        
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: .languageDidUpdate, object: languageCode)
            self.objectWillChange.send()
        }
    }
    
    func getLocalizedString(_ key: String) -> String {
        return Bundle.languageBundle.localizedString(forKey: key, value: nil, table: nil)
    }
    
    func getCurrentLanguage() -> String {
        return currentLanguage
    }
    
    func getSupportedLanguages() -> [String] {
        return supportedLanguages
    }
}

struct LocalizedViewModifier: ViewModifier {
    @ObservedObject private var languageCenter = LanguageCenter.shared
    
    func body(content: Content) -> some View {
        content
            .onReceive(NotificationCenter.default.publisher(for: .languageDidUpdate)) { _ in
                DispatchQueue.main.async {
                    self.languageCenter.objectWillChange.send()
                }
            }
    }
}

func LocalStr(_ key: String, comment: String = "") -> String {
    return LanguageCenter.shared.getLocalizedString(key)
}

// MARK: - Bundle Extension for Language Support
extension Bundle {
    private static var _languageBundle: Bundle?
    
    static var languageBundle: Bundle {
        return _languageBundle ?? Bundle.main
    }
    
    static func updateLanguage(_ languageCode: String) {
        UserDefaults.standard.set([languageCode], forKey: "AppleLanguages")
        UserDefaults.standard.set(languageCode, forKey: "AppLanguage")
        UserDefaults.standard.synchronize()
        
        if let bundlePath = Bundle.main.path(forResource: languageCode, ofType: "lproj"),
           let languageBundle = Bundle(path: bundlePath) {
            _languageBundle = languageBundle
        } else {
            _languageBundle = Bundle.main
        }
    }
    
    static func resetLanguageBundle() {
        _languageBundle = nil
    }
}

extension Notification.Name {
    static let languageDidUpdate = Notification.Name("languageDidUpdate")
}

extension String {
    func localstr() -> String {
        return LanguageCenter.shared.getLocalizedString(self)
    }
}

extension View {
    func localview() -> some View {
        self.modifier(LocalizedViewModifier())
    }
}
