import AppKit
import SwiftUI

struct PromptEditorView: View {
    @EnvironmentObject private var store: PromptStore
    @State private var title: String
    @State private var mainCategory: String
    @State private var subcategory: String
    @State private var displayedUpdatedAt: Date
    @State private var draftBodies: [ExpertiseLevel: String]
    @State private var savedBodies: [ExpertiseLevel: String]
    @State private var selectedLevel: ExpertiseLevel = .beginner
    @State private var savedTitle: String
    @State private var savedMainCategory: String
    @State private var savedSubcategory: String
    @State private var confirmDelete = false
    @State private var isEditing = false
    @State private var addMainPresented = false
    @State private var addSubPresented = false
    @State private var newMainName = ""
    @State private var newSubName = ""

    private let promptID: UUID
    private let createdAt: Date
    private let onSave: (Prompt) -> Void
    private let onDelete: () -> Void
    private let onDuplicate: () -> Void

    private var bodyBinding: Binding<String> {
        Binding(
            get: { draftBodies[selectedLevel] ?? "" },
            set: { draftBodies[selectedLevel] = $0 }
        )
    }

    private var estimatedTokens: Int {
        TokenEstimator.estimateTokens(for: draftBodies[selectedLevel] ?? "")
    }

    private var liveFavorite: Bool {
        store.prompts.first(where: { $0.id == promptID })?.isFavorite ?? false
    }

    private var draftTaxonomyLine: String {
        "\(LibraryTaxonomy.normalizeMain(mainCategory)) › \(LibraryTaxonomy.normalizeSub(subcategory))"
    }

    private var isDirty: Bool {
        let t = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let m = LibraryTaxonomy.normalizeMain(mainCategory)
        let s = LibraryTaxonomy.normalizeSub(subcategory)
        if t != savedTitle || m != savedMainCategory || s != savedSubcategory { return true }
        return ExpertiseLevel.allCases.contains { level in
            (draftBodies[level] ?? "") != (savedBodies[level] ?? "")
        }
    }

    init(prompt: Prompt, onSave: @escaping (Prompt) -> Void, onDelete: @escaping () -> Void, onDuplicate: @escaping () -> Void) {
        promptID = prompt.id
        createdAt = prompt.createdAt
        let initialTitle = prompt.title.trimmingCharacters(in: .whitespacesAndNewlines)
        let m = prompt.normalizedMainCategory
        let s = prompt.normalizedSubcategory
        let bodiesSnapshot = Dictionary(uniqueKeysWithValues: ExpertiseLevel.allCases.map { ($0, prompt.text(for: $0)) })
        _title = State(initialValue: prompt.title)
        _mainCategory = State(initialValue: prompt.mainCategory)
        _subcategory = State(initialValue: prompt.subcategory)
        _displayedUpdatedAt = State(initialValue: prompt.updatedAt)
        _draftBodies = State(initialValue: bodiesSnapshot)
        _savedBodies = State(initialValue: bodiesSnapshot)
        _savedTitle = State(initialValue: initialTitle)
        _savedMainCategory = State(initialValue: m)
        _savedSubcategory = State(initialValue: s)
        self.onSave = onSave
        self.onDelete = onDelete
        self.onDuplicate = onDuplicate
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                labeledField("Prompt") {
                    if isEditing {
                        TextField("Title", text: $title)
                            .textFieldStyle(.roundedBorder)
                            .promptZenActivateOnTap()

                        Picker("Main category", selection: $mainCategory) {
                            ForEach(store.allMainCategoriesOrdered, id: \.self) { name in
                                Text(name).tag(name)
                            }
                        }
                        .onChange(of: mainCategory) { _, _ in
                            let subs = store.subcategories(for: mainCategory)
                            if !subs.contains(where: { $0.caseInsensitiveCompare(subcategory) == .orderedSame }) {
                                subcategory = subs.first ?? LibraryTaxonomy.fallbackSub
                            }
                        }

                        Picker("Subcategory", selection: $subcategory) {
                            ForEach(store.subcategories(for: mainCategory), id: \.self) { name in
                                Text(name).tag(name)
                            }
                        }

                        HStack(spacing: 12) {
                            Button("New main category…") {
                                newMainName = ""
                                addMainPresented = true
                            }
                            .buttonStyle(.borderless)

                            Button("New subcategory…") {
                                newSubName = ""
                                addSubPresented = true
                            }
                            .buttonStyle(.borderless)
                        }
                        .font(.caption)
                    } else {
                        Text(title.isEmpty ? "Untitled" : title)
                            .font(.title2.weight(.semibold))
                            .textSelection(.enabled)
                        Text(draftTaxonomyLine)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .textSelection(.enabled)
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Body")
                            .font(.headline)
                        Spacer()
                        Picker("Level", selection: $selectedLevel) {
                            ForEach(ExpertiseLevel.allCases) { level in
                                Text(level.displayName).tag(level)
                            }
                        }
                        .pickerStyle(.segmented)
                        .frame(maxWidth: 360)
                    }
                    Text("Beginner = shorter; Senior/Staff add depth. Each level is stored separately.")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    if isEditing {
                        TextEditor(text: bodyBinding)
                            .font(.body)
                            .frame(minHeight: 280)
                            .padding(6)
                            .background(RoundedRectangle(cornerRadius: 6).fill(Color(nsColor: .textBackgroundColor)))
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .strokeBorder(Color(nsColor: .separatorColor), lineWidth: 1)
                            )
                            .promptZenActivateOnTap()
                    } else {
                        ScrollView {
                            Text(draftBodies[selectedLevel] ?? "")
                                .font(.body)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .textSelection(.enabled)
                        }
                        .frame(minHeight: 280)
                        .padding(10)
                        .background(RoundedRectangle(cornerRadius: 6).fill(Color(nsColor: .textBackgroundColor)))
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .strokeBorder(Color(nsColor: .separatorColor), lineWidth: 1)
                        )
                    }
                }

                if isEditing {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Quick enhance")
                            .font(.headline)
                        HStack(spacing: 10) {
                            Button("Trim edges") {
                                let key = selectedLevel
                                draftBodies[key] = PromptEnhancer.trimWhitespace(draftBodies[key] ?? "")
                                persist()
                            }
                            Button("Strip trailing space") {
                                let key = selectedLevel
                                draftBodies[key] = PromptEnhancer.stripTrailingWhitespacePerLine(draftBodies[key] ?? "")
                                persist()
                            }
                            Button("Collapse blank lines") {
                                let key = selectedLevel
                                draftBodies[key] = PromptEnhancer.collapseBlankLines(draftBodies[key] ?? "")
                                persist()
                            }
                        }
                        .fixedSize(horizontal: false, vertical: true)
                    }
                }

                Divider()

                VStack(alignment: .leading, spacing: 12) {
                    Text("Details")
                        .font(.headline)

                    HStack(alignment: .firstTextBaseline, spacing: 32) {
                        metaBlock("Est. tokens (\(selectedLevel.displayName))") {
                            Text("~\(estimatedTokens)")
                                .font(.subheadline)
                                .monospacedDigit()
                        }
                        metaBlock("Created") {
                            Text(createdAt.formatted(date: .abbreviated, time: .shortened))
                                .font(.subheadline)
                        }
                        metaBlock("Updated") {
                            Text(displayedUpdatedAt.formatted(date: .abbreviated, time: .shortened))
                                .font(.subheadline)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    Text("Token count uses a local heuristic (~4 UTF-8 bytes per token); models differ.")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(RoundedRectangle(cornerRadius: 8).fill(Color(nsColor: .controlBackgroundColor).opacity(0.55)))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(Color(nsColor: .separatorColor).opacity(0.45), lineWidth: 1)
                )
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .onAppear {
            PromptZenAppActivation.activateKeyWindowHierarchy()
        }
        .onDisappear {
            if isDirty {
                persist()
            }
        }
        .navigationTitle(title.isEmpty ? "Untitled" : title)
        .alert("New main category", isPresented: $addMainPresented) {
            TextField("Name", text: $newMainName)
            Button("Add") {
                store.addMainCategory(newMainName)
                mainCategory = newMainName.trimmingCharacters(in: .whitespacesAndNewlines)
                newMainName = ""
            }
            Button("Cancel", role: .cancel) { newMainName = "" }
        } message: {
            Text("It will appear in the Library sidebar and in this picker.")
        }
        .alert("New subcategory", isPresented: $addSubPresented) {
            TextField("Name", text: $newSubName)
            Button("Add") {
                let name = newSubName.trimmingCharacters(in: .whitespacesAndNewlines)
                store.addSubcategory(to: mainCategory, name: name)
                subcategory = name
                newSubName = ""
            }
            Button("Cancel", role: .cancel) { newSubName = "" }
        } message: {
            Text("Under “\(LibraryTaxonomy.normalizeMain(mainCategory))”.")
        }
        .toolbar {
            ToolbarItem(placement: .automatic) {
                Button {
                    store.toggleFavorite(id: promptID)
                } label: {
                    Image(systemName: liveFavorite ? "star.fill" : "star")
                }
                .help(liveFavorite ? "Remove from favorites" : "Add to favorites")
            }
            if isEditing, isDirty {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        persist()
                    }
                    .keyboardShortcut("s", modifiers: [.command])
                }
            }
            ToolbarItemGroup(placement: .primaryAction) {
                if isEditing {
                    Button("Done") {
                        if isDirty {
                            persist()
                        }
                        isEditing = false
                    }
                } else {
                    Button("Edit") {
                        isEditing = true
                    }
                }
                Menu {
                    Button("Copy body (\(selectedLevel.displayName))") {
                        IDEExport.copyPlain(draftBodies[selectedLevel] ?? "")
                    }
                    Button("Copy with IDE header (\(selectedLevel.displayName))") {
                        IDEExport.copyWithIDEHeader(
                            title: title.isEmpty ? "Untitled" : title,
                            category: draftTaxonomyLine,
                            body: draftBodies[selectedLevel] ?? ""
                        )
                    }
                } label: {
                    Label("Copy for IDE", systemImage: "doc.on.doc")
                }
                Button {
                    persist()
                    onDuplicate()
                } label: {
                    Label("Duplicate", systemImage: "plus.square.on.square")
                }
                Button {
                    confirmDelete = true
                } label: {
                    Label("Delete", systemImage: "trash")
                }
                .tint(.red)
                .help("Delete this prompt")
            }
        }
        .confirmationDialog(
            "Delete this prompt?",
            isPresented: $confirmDelete,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                onDelete()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This cannot be undone.")
        }
    }

    private func metaBlock<Content: View>(_ title: String, @ViewBuilder value: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            value()
        }
        .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
    }

    private func labeledField<Content: View>(_ label: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label)
                .font(.headline)
            VStack(alignment: .leading, spacing: 10) {
                content()
            }
        }
    }

    private func persist() {
        let now = Date()
        let t = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let m = LibraryTaxonomy.normalizeMain(mainCategory)
        let s = LibraryTaxonomy.normalizeSub(subcategory)
        let fav = store.prompts.first(where: { $0.id == promptID })?.isFavorite ?? false
        let p = Prompt(
            id: promptID,
            title: t,
            bodies: draftBodies,
            mainCategory: m,
            subcategory: s,
            isFavorite: fav,
            createdAt: createdAt,
            updatedAt: now
        )
        onSave(p)
        displayedUpdatedAt = now
        savedTitle = t
        savedMainCategory = m
        savedSubcategory = s
        savedBodies = Dictionary(uniqueKeysWithValues: ExpertiseLevel.allCases.map { ($0, draftBodies[$0] ?? "") })
    }
}
