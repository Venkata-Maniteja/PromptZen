import AppKit
import SwiftUI

struct PromptEditorView: View {
    @State private var title: String
    @State private var category: String
    @State private var displayedUpdatedAt: Date
    @State private var draftBodies: [ExpertiseLevel: String]
    @State private var savedBodies: [ExpertiseLevel: String]
    @State private var selectedLevel: ExpertiseLevel = .beginner
    @State private var savedTitle: String
    @State private var savedCategory: String
    @State private var confirmDelete = false

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

    private var isDirty: Bool {
        let t = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let c = category.trimmingCharacters(in: .whitespacesAndNewlines)
        if t != savedTitle || c != savedCategory { return true }
        return ExpertiseLevel.allCases.contains { level in
            (draftBodies[level] ?? "") != (savedBodies[level] ?? "")
        }
    }

    init(prompt: Prompt, onSave: @escaping (Prompt) -> Void, onDelete: @escaping () -> Void, onDuplicate: @escaping () -> Void) {
        promptID = prompt.id
        createdAt = prompt.createdAt
        let initialTitle = prompt.title.trimmingCharacters(in: .whitespacesAndNewlines)
        let initialCategory = prompt.category.trimmingCharacters(in: .whitespacesAndNewlines)
        let bodiesSnapshot = Dictionary(uniqueKeysWithValues: ExpertiseLevel.allCases.map { ($0, prompt.text(for: $0)) })
        _title = State(initialValue: prompt.title)
        _category = State(initialValue: prompt.category)
        _displayedUpdatedAt = State(initialValue: prompt.updatedAt)
        _draftBodies = State(initialValue: bodiesSnapshot)
        _savedBodies = State(initialValue: bodiesSnapshot)
        _savedTitle = State(initialValue: initialTitle)
        _savedCategory = State(initialValue: initialCategory)
        self.onSave = onSave
        self.onDelete = onDelete
        self.onDuplicate = onDuplicate
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                labeledField("Prompt") {
                    TextField("Title", text: $title)
                        .textFieldStyle(.roundedBorder)
                        .promptZenActivateOnTap()
                    TextField("Category", text: $category)
                        .textFieldStyle(.roundedBorder)
                        .promptZenActivateOnTap()
                    Text("Examples: Feature, Debug, Maintenance, Refactor, Testing, Review, Docs, Security, DX")
                        .font(.caption)
                        .foregroundStyle(.secondary)
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
                }

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
        .toolbar {
            if isDirty {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        persist()
                    }
                    .keyboardShortcut("s", modifiers: [.command])
                }
            }
            ToolbarItemGroup(placement: .primaryAction) {
                Menu {
                    Button("Copy body (\(selectedLevel.displayName))") {
                        IDEExport.copyPlain(draftBodies[selectedLevel] ?? "")
                    }
                    Button("Copy with IDE header (\(selectedLevel.displayName))") {
                        IDEExport.copyWithIDEHeader(
                            title: title.isEmpty ? "Untitled" : title,
                            category: category.isEmpty ? "Uncategorized" : category,
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
        let c = category.trimmingCharacters(in: .whitespacesAndNewlines)
        let p = Prompt(
            id: promptID,
            title: t,
            bodies: draftBodies,
            category: c,
            createdAt: createdAt,
            updatedAt: now
        )
        onSave(p)
        displayedUpdatedAt = now
        savedTitle = t
        savedCategory = c
        savedBodies = Dictionary(uniqueKeysWithValues: ExpertiseLevel.allCases.map { ($0, draftBodies[$0] ?? "") })
    }
}
