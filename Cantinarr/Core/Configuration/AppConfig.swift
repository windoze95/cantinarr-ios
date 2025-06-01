// File: AppConfig.swift
// Purpose: Defines AppConfig component for Cantinarr

// This file uses UIKit which is only available on Apple platforms.
#if canImport(UIKit)
import UIKit

//  Centralised tunable constants.
enum AppConfig {
    static let debounceInterval: Double = 0.3
    static let prefetchThreshold = 5 // items before list end
}

extension UIApplication {
    /// Force any current first responder to resign.
    func endEditing() {
        sendAction(#selector(UIResponder.resignFirstResponder),
                   to: nil, from: nil, for: nil)
    }
}
#endif
