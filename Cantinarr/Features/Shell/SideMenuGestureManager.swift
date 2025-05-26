// File: SideMenuGestureManager.swift
// Purpose: Encapsulates drag and tap gestures for the side menu

import SwiftUI

/// Handles the gestures that control the slide-out side menu.
/// The `dragThreshold` determines how far the user must drag before the
/// menu opens or closes. Use this helper in `RootShellView` to keep gesture
/// logic separate from view layout code.
struct SideMenuGestureManager {
    /// Called when a drag or tap should open the menu.
    var openMenu: () -> Void
    /// Called when a drag or tap should close the menu.
    var closeMenu: () -> Void

    /// Minimum drag movement before a drag is considered.
    var minDragDistance: CGFloat = 20
    /// Points the user must drag horizontally before the menu toggles.
    var dragThreshold: CGFloat = 40

    /// Dragging right past `dragThreshold` opens the menu.
    func openDragGesture() -> some Gesture {
        DragGesture(minimumDistance: minDragDistance)
            .onEnded { value in
                if value.translation.width > dragThreshold {
                    openMenu()
                }
            }
    }

    /// Dragging left past `dragThreshold` closes the menu.
    func closeDragGesture() -> some Gesture {
        DragGesture(minimumDistance: minDragDistance)
            .onEnded { value in
                if value.translation.width < -dragThreshold {
                    closeMenu()
                }
            }
    }

    /// Tap gesture used to dismiss the menu overlay.
    func closeTapGesture() -> some Gesture {
        TapGesture().onEnded { closeMenu() }
    }
}
