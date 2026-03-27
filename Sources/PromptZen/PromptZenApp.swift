import SwiftUI

@main
struct PromptZenApp: App {
    @NSApplicationDelegateAdaptor(PromptZenNSAppDelegate.self) private var appDelegate
    @StateObject private var store = PromptStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(store)
                .frame(minWidth: 1240, minHeight: 560)
        }
        .defaultSize(width: 980, height: 620)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("New Prompt") {
                    NotificationCenter.default.post(name: .promptZenNewPrompt, object: nil)
                }
                .keyboardShortcut("n", modifiers: [.command])
            }
        }
    }
}

extension Notification.Name {
    static let promptZenNewPrompt = Notification.Name("PromptZenNewPrompt")
}
