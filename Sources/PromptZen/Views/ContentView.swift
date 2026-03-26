import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var store: PromptStore
    @State private var columnVisibility: NavigationSplitViewVisibility = .doubleColumn
    @State private var section: MainSection = .library
    @State private var creatorDraft: Prompt?

    enum MainSection: String, CaseIterable, Identifiable, Hashable {
        case library = "Library"
        case playground = "Playground"
        var id: String { rawValue }
    }

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            sidebarColumn
                .navigationSplitViewColumnWidth(min: 240, ideal: 280, max: 360)
        } detail: {
            mainColumn
                .navigationSplitViewColumnWidth(min: 520, ideal: 720)
                .layoutPriority(1)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .navigationTitle("PromptZen")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                if section == .library {
                    Button {
                        store.selectedPromptID = nil
                        creatorDraft = Prompt.emptyForNew(category: store.categories.first ?? "")
                        PromptZenAppActivation.activateKeyWindowHierarchy()
                    } label: {
                        Label("New Prompt", systemImage: "plus")
                    }
                }
            }
        }
        .sheet(item: $creatorDraft) { draft in
            NavigationStack {
                PromptCreatorView(initial: draft, onSave: { created in
                    store.add(created)
                    creatorDraft = nil
                    store.selectedPromptID = created.id
                }, onCancel: {
                    creatorDraft = nil
                })
            }
            .frame(minWidth: 560, minHeight: 520)
            .presentationBackground(.regularMaterial)
        }
        .onReceive(NotificationCenter.default.publisher(for: .promptZenNewPrompt)) { _ in
            section = .library
            store.selectedPromptID = nil
            creatorDraft = Prompt.emptyForNew(category: store.categories.first ?? "")
            PromptZenAppActivation.activateKeyWindowHierarchy()
        }
    }

    private var sidebarColumn: some View {
        VStack(alignment: .leading, spacing: 0) {
            Picker("Mode", selection: $section) {
                ForEach(MainSection.allCases) { s in
                    Text(s.rawValue).tag(s)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .padding(.horizontal, 10)
            .padding(.top, 10)
            .padding(.bottom, 8)

            if section == .library, !store.prompts.isEmpty {
                librarySearchAndList
            } else if section == .playground {
                Text("Estimate tokens and cost for pasted text.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 12)
                Spacer(minLength: 0)
            } else {
                Spacer(minLength: 0)
            }
        }
    }

    private var librarySearchAndList: some View {
        VStack(alignment: .leading, spacing: 0) {
            TextField("Search title, body, category…", text: $store.searchText)
                .textFieldStyle(.roundedBorder)
                .padding(.horizontal, 12)
                .padding(.bottom, 8)

            List(selection: $store.selectedPromptID) {
                Section("Categories") {
                    categoryRow(nil, label: "All")
                    ForEach(store.categories, id: \.self) { cat in
                        categoryRow(cat, label: cat)
                    }
                }
                Section("Prompts") {
                    ForEach(store.filteredPrompts) { p in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(p.title.isEmpty ? "Untitled" : p.title)
                                .font(.headline)
                            Text(p.category.isEmpty ? "Uncategorized" : p.category)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .tag(p.id as UUID?)
                    }
                }
            }
            .listStyle(.sidebar)
        }
    }

    @ViewBuilder
    private var mainColumn: some View {
        switch section {
        case .playground:
            PlaygroundView()
        case .library:
            if store.prompts.isEmpty {
                LibraryEmptyStateView(creatorDraft: $creatorDraft)
            } else {
                NavigationStack {
                    if let id = store.selectedPromptID, let prompt = store.prompts.first(where: { $0.id == id }) {
                        PromptEditorView(prompt: prompt, onSave: { store.update($0) }, onDelete: {
                            store.delete(id: id)
                        }, onDuplicate: { store.duplicate(id: id) })
                    } else {
                        ContentUnavailableView(
                            "Select a prompt",
                            systemImage: "text.alignleft",
                            description: Text("Choose a prompt from the list or use New Prompt to add one.")
                        )
                    }
                }
            }
        }
    }

    private func categoryRow(_ category: String?, label: String) -> some View {
        Button {
            store.selectedCategory = category
        } label: {
            HStack {
                Text(label)
                Spacer()
                if store.selectedCategory == category {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .buttonStyle(.plain)
    }
}
