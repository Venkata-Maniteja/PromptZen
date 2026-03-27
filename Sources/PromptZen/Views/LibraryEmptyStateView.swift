import SwiftUI

struct LibraryEmptyStateView: View {
    @Binding var creatorDraft: Prompt?

    var body: some View {
        ContentUnavailableView {
            Label("Your library is empty", systemImage: "text.book.closed")
                .symbolRenderingMode(.hierarchical)
        } description: {
            Text("Create a prompt under a main category and subcategory, estimate tokens in the playground, and copy into your editor.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
        } actions: {
            Button {
                creatorDraft = Prompt.emptyForNew()
                PromptZenAppActivation.activateKeyWindowHierarchy()
            } label: {
                Label("New Prompt", systemImage: "plus.circle.fill")
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
