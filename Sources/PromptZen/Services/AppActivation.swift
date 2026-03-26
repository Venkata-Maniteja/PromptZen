import AppKit

/// Ensures PromptZen is the active app and a suitable window is key so typing does not go to another app (e.g. an IDE).
@MainActor
enum PromptZenAppActivation {
    static func activateKeyWindowHierarchy() {
        NSApp.activate()
        for window in NSApp.windows.reversed() where window.isVisible && window.canBecomeKey {
            window.makeKeyAndOrderFront(nil)
            break
        }
    }

    /// Prefer the window the user clicked (e.g. local event monitor).
    static func activate(window: NSWindow) {
        NSApp.activate()
        window.makeKeyAndOrderFront(nil)
    }
}
