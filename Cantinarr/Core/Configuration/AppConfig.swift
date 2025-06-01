// File: AppConfig.swift
// Purpose: Defines AppConfig component for Cantinarr

// Centralised tunable constants available on all platforms.
enum AppConfig {
    static let debounceInterval: Double = 0.3
    static let prefetchThreshold = 5 // items before list end
}

// UIApplication utilities are only available on Apple platforms.
#if canImport(UIKit)
import UIKit

extension UIApplication {
    /// Force any current first responder to resign.
    func endEditing() {
        sendAction(#selector(UIResponder.resignFirstResponder),
                   to: nil, from: nil, for: nil)
    }
}
#endif
