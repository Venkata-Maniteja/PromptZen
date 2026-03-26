import SwiftUI

extension View {
    /// When the user taps into text UI, ensure PromptZen (not another app) receives keyboard input.
    func promptZenActivateOnTap() -> some View {
        simultaneousGesture(
            TapGesture().onEnded { _ in
                PromptZenAppActivation.activateKeyWindowHierarchy()
            }
        )
    }
}
