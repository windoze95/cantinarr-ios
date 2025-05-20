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
