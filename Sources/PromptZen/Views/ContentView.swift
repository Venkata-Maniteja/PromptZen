import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var store: PromptStore
    @State private var libraryColumnVisibility: NavigationSplitViewVisibility = .all
    @State private var section: MainSection = .library
    @State private var creatorDraft: Prompt?
    @State private var addMainPresented = false
    @State private var addSubPresented = false
    @State private var newMainName = ""
    @State private var newSubName = ""
    @State private var addSubTargetMain: String?

    enum MainSection: String, CaseIterable, Identifiable, Hashable {
        case library = "Library"
        case playground = "Playground"
        var id: String { rawValue }
    }

    var body: some View {
        Group {
            if section == .playground {
                NavigationSplitView {
                    modeOnlySidebar
                        .navigationSplitViewColumnWidth(min: 240, ideal: 280, max: 360)
                } detail: {
                    PlaygroundView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            } else {
                NavigationSplitView(columnVisibility: $libraryColumnVisibility) {
                    libraryMainCategoriesColumn
                        .navigationSplitViewColumnWidth(min: 180, ideal: 220, max: 280)
                } content: {
                    librarySubcategoriesColumn
                        .navigationSplitViewColumnWidth(min: 160, ideal: 200, max: 260)
                } detail: {
                    if store.prompts.isEmpty {
                        LibraryEmptyStateView(creatorDraft: $creatorDraft)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        NavigationSplitView {
                            libraryPromptListColumn
                                .navigationSplitViewColumnWidth(min: 200, ideal: 260, max: 340)
                        } detail: {
                            libraryPromptDetailColumn
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                        }
                    }
                }
            }
        }
        .navigationTitle("PromptZen")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                if section == .library {
                    Button {
                        store.selectedPromptID = nil
                        creatorDraft = store.newPromptDraft()
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
                    store.selectTaxonomy(
                        .library(
                            main: created.normalizedMainCategory,
                            sub: created.normalizedSubcategory
                        )
                    )
                    store.selectedPromptID = created.id
                }, onCancel: {
                    creatorDraft = nil
                })
            }
            .environmentObject(store)
            .frame(minWidth: 560, minHeight: 520)
            .presentationBackground(.regularMaterial)
        }
        .alert("New main category", isPresented: $addMainPresented) {
            TextField("Name", text: $newMainName)
            Button("Add") {
                store.addMainCategory(newMainName)
                newMainName = ""
            }
            Button("Cancel", role: .cancel) {
                newMainName = ""
            }
        } message: {
            Text("Appears under Library with the built-in categories.")
        }
        .alert("New subcategory", isPresented: $addSubPresented) {
            TextField("Name", text: $newSubName)
            Button("Add") {
                if let main = addSubTargetMain {
                    store.addSubcategory(to: main, name: newSubName)
                }
                newSubName = ""
                addSubTargetMain = nil
            }
            Button("Cancel", role: .cancel) {
                newSubName = ""
                addSubTargetMain = nil
            }
        } message: {
            Text(addSubTargetMain.map { "Under “\($0)”." } ?? "")
        }
        .onReceive(NotificationCenter.default.publisher(for: .promptZenNewPrompt)) { _ in
            section = .library
            store.selectedPromptID = nil
            creatorDraft = store.newPromptDraft()
            PromptZenAppActivation.activateKeyWindowHierarchy()
        }
        .onAppear {
            store.ensureDefaultTaxonomySelection()
        }
        .onChange(of: store.selectedTaxonomy) { _, _ in
            syncSelectionToListedPrompts()
        }
        .onChange(of: store.listedPrompts.map(\.id)) { _, _ in
            syncSelectionToListedPrompts()
        }
    }

    private func syncSelectionToListedPrompts() {
        let ids = Set(store.listedPrompts.map(\.id))
        if let sid = store.selectedPromptID, !ids.contains(sid) {
            store.selectedPromptID = store.listedPrompts.first?.id
        }
    }

    private var modeOnlySidebar: some View {
        VStack(alignment: .leading, spacing: 0) {
            modePicker
            Text("Estimate tokens and cost for pasted text.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 12)
                .padding(.top, 8)
            Spacer(minLength: 0)
        }
    }

    /// Column 1: flat main categories (no disclosure / tree).
    private var libraryMainCategoriesColumn: some View {
        VStack(alignment: .leading, spacing: 0) {
            modePicker
            TextField("Search title, body, taxonomy…", text: $store.searchText)
                .textFieldStyle(.roundedBorder)
                .padding(.horizontal, 12)
                .padding(.bottom, 8)

            // Explicit buttons: `List(selection:)` with optional enum tags is unreliable on macOS.
            List {
                Section {
                    if store.favoriteMainsOrdered.isEmpty {
                        Text("No favorites yet")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(store.favoriteMainsOrdered, id: \.self) { main in
                            mainCategoryRow(pick: .favorites(main))
                        }
                    }
                } header: {
                    Text("Favorites")
                }

                Section {
                    ForEach(store.allMainCategoriesOrdered, id: \.self) { main in
                        mainCategoryRow(pick: .library(main))
                            .contextMenu {
                                Button("Add subcategory…") {
                                    addSubTargetMain = main
                                    addSubPresented = true
                                }
                            }
                    }
                } header: {
                    Text("Library")
                }
            }
            .listStyle(.sidebar)

            Button {
                addMainPresented = true
            } label: {
                Label("Add main category…", systemImage: "folder.badge.plus")
            }
            .buttonStyle(.borderless)
            .foregroundStyle(Color.accentColor)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
    }

    private func mainCategoryRow(pick: TaxonomyMainPick) -> some View {
        let selected = store.selectedTaxonomyMain == pick
        let iconName: String = switch pick {
        case .favorites: "star.fill"
        case .library: "folder"
        }
        return Button {
            store.selectTaxonomyMain(pick)
        } label: {
            HStack(spacing: 8) {
                Image(systemName: iconName)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .frame(width: 18, alignment: .center)
                Text(pick.main)
                    .font(.body)
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.leading)
                Spacer(minLength: 0)
                if selected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.secondary)
                        .imageScale(.small)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    /// Column 2: subcategories for the selected main (Library vs Favorites).
    private var librarySubcategoriesColumn: some View {
        Group {
            if store.selectedTaxonomyMain == nil {
                ContentUnavailableView(
                    "Select a category",
                    systemImage: "folder",
                    description: Text("Choose a main category in the first column.")
                )
            } else {
                switch store.selectedTaxonomyMain! {
                case .library(let main):
                    subcategoryList(
                        title: main,
                        subs: store.subcategories(for: main),
                        emptyMessage: "No subcategories. Add one via the sidebar context menu or when editing a prompt."
                    ) { sub in
                        SidebarSelection.library(main: main, sub: sub)
                    } select: { tax in
                        store.selectTaxonomy(tax)
                    }
                case .favorites(let main):
                    let subs = store.favoriteSubs(for: main)
                    subcategoryList(
                        title: main,
                        subs: subs,
                        emptyMessage: "No favorite prompts in this category yet."
                    ) { sub in
                        SidebarSelection.favorites(main: main, sub: sub)
                    } select: { tax in
                        store.selectTaxonomy(tax)
                    }
                }
            }
        }
    }

    private func subcategoryList(
        title: String,
        subs: [String],
        emptyMessage: String,
        taxForSub: @escaping (String) -> SidebarSelection,
        select: @escaping (SidebarSelection) -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title)
                .font(.headline)
                .padding(.horizontal, 12)
                .padding(.top, 10)
                .padding(.bottom, 6)

            if subs.isEmpty {
                ContentUnavailableView(
                    "No subcategories",
                    systemImage: "rectangle.stack",
                    description: Text(emptyMessage)
                )
            } else {
                List {
                    ForEach(subs, id: \.self) { sub in
                        let tax = taxForSub(sub)
                        subcategoryRow(tax: tax) {
                            select(tax)
                        }
                    }
                }
                .listStyle(.sidebar)
            }
        }
    }

    private func subcategoryRow(tax: SidebarSelection, select: @escaping () -> Void) -> some View {
        let selected = taxonomySelectionsEqual(store.selectedTaxonomy, tax)

        return Button(action: select) {
            HStack {
                Image(systemName: "doc.text")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(tax.sub)
                    .font(.subheadline)
                Spacer()
                if selected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.secondary)
                        .imageScale(.small)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func taxonomySelectionsEqual(_ a: SidebarSelection?, _ b: SidebarSelection) -> Bool {
        guard let a else { return false }
        switch (a, b) {
        case (.library(let m1, let s1), .library(let m2, let s2)):
            return m1.lowercased() == m2.lowercased() && s1.lowercased() == s2.lowercased()
        case (.favorites(let m1, let s1), .favorites(let m2, let s2)):
            return m1.lowercased() == m2.lowercased() && s1.lowercased() == s2.lowercased()
        default:
            return false
        }
    }

    private var modePicker: some View {
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
    }

    private var libraryPromptListColumn: some View {
        Group {
            if store.selectedTaxonomy == nil {
                ContentUnavailableView(
                    "Choose a subcategory",
                    systemImage: "rectangle.stack",
                    description: Text("Pick a subcategory in the second column.")
                )
            } else if store.listedPrompts.isEmpty {
                ContentUnavailableView(
                    "No prompts",
                    systemImage: "text.alignleft",
                    description: Text("Nothing here yet. Use New Prompt to add one in this folder.")
                )
            } else {
                List(selection: $store.selectedPromptID) {
                    ForEach(store.listedPrompts) { p in
                        HStack(alignment: .top, spacing: 8) {
                            if p.isFavorite {
                                Image(systemName: "star.fill")
                                    .font(.caption)
                                    .foregroundStyle(.yellow.opacity(0.9))
                            }
                            VStack(alignment: .leading, spacing: 4) {
                                Text(p.title.isEmpty ? "Untitled" : p.title)
                                    .font(.headline)
                                Text(p.taxonomyDisplayLine)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .tag(p.id as UUID?)
                    }
                }
                .listStyle(.sidebar)
            }
        }
    }

    private var detailPrompt: Prompt? {
        guard let id = store.selectedPromptID else { return nil }
        return store.listedPrompts.first { $0.id == id }
    }

    /// Prompt editor / selection (only used when the library has at least one prompt).
    @ViewBuilder
    private var libraryPromptDetailColumn: some View {
        NavigationStack {
            if let prompt = detailPrompt {
                PromptEditorView(
                    prompt: prompt,
                    onSave: { store.update($0) },
                    onDelete: { store.delete(id: prompt.id) },
                    onDuplicate: { store.duplicate(id: prompt.id) }
                )
            } else {
                ContentUnavailableView(
                    "Select a prompt",
                    systemImage: "text.alignleft",
                    description: Text("Choose a prompt from the list or create a new one.")
                )
            }
        }
    }
}
