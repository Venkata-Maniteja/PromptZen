import AppKit

/// Ensures PromptZen behaves as a normal GUI app and re-asserts key status on mouse clicks in our windows.
/// (SwiftUI + IDE workflows can otherwise leave another app receiving keyboard input.)
final class PromptZenNSAppDelegate: NSObject, NSApplicationDelegate {
    private var mouseDownMonitor: Any?

    func applicationWillFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        mouseDownMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown, .otherMouseDown]) { event in
            guard let window = event.window else { return event }
            guard NSApp.windows.contains(where: { $0 === window }) else { return event }
            Task { @MainActor in
                PromptZenAppActivation.activate(window: window)
            }
            return event
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        if let monitor = mouseDownMonitor {
            NSEvent.removeMonitor(monitor)
            mouseDownMonitor = nil
        }
    }
}
