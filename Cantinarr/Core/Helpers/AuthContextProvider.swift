// File: AuthContextProvider.swift
// Purpose: Defines AuthContextProvider component for Cantinarr

import AuthenticationServices
import UIKit

/// Supplies the window for ASWebAuthenticationSession to present in.
final class AuthContextProvider: NSObject, ASWebAuthenticationPresentationContextProviding {
    func presentationAnchor(for _: ASWebAuthenticationSession) -> ASPresentationAnchor {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first { $0.isKeyWindow }
            ?? ASPresentationAnchor()
    }
}
