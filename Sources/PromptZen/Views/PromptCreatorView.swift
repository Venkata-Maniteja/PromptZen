import AppKit
import SwiftUI

struct PromptCreatorView: View {
    @EnvironmentObject private var store: PromptStore
    let initial: Prompt
    let onSave: (Prompt) -> Void
    let onCancel: () -> Void

    @State private var title: String
    @State private var mainCategory: String
    @State private var subcategory: String
    @State private var draftBodies: [ExpertiseLevel: String]
    @State private var selectedLevel: ExpertiseLevel = .beginner
    @FocusState private var titleFocused: Bool
    @State private var addMainPresented = false
    @State private var addSubPresented = false
    @State private var newMainName = ""
    @State private var newSubName = ""

    private var bodyBinding: Binding<String> {
        Binding(
            get: { draftBodies[selectedLevel] ?? "" },
            set: { draftBodies[selectedLevel] = $0 }
        )
    }

    private var canSave: Bool {
        let t = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let anyBody = ExpertiseLevel.allCases.contains { level in
            !(draftBodies[level] ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
        return !t.isEmpty || anyBody
    }

    init(initial: Prompt, onSave: @escaping (Prompt) -> Void, onCancel: @escaping () -> Void) {
        self.initial = initial
        self.onSave = onSave
        self.onCancel = onCancel
        _title = State(initialValue: initial.title)
        _mainCategory = State(initialValue: initial.mainCategory)
        _subcategory = State(initialValue: initial.subcategory)
        _draftBodies = State(
            initialValue: Dictionary(uniqueKeysWithValues: ExpertiseLevel.allCases.map { ($0, initial.text(for: $0)) })
        )
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                labeledField("Title") {
                    TextField("Title", text: $title)
                        .textFieldStyle(.roundedBorder)
                        .focused($titleFocused)
                        .promptZenActivateOnTap()
                }
                labeledField("Taxonomy") {
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
                        Button("New subcategory…") {
                            newSubName = ""
                            addSubPresented = true
                        }
                    }
                    .buttonStyle(.borderless)
                    .font(.caption)
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
                    Button("Copy Beginner → Senior & Staff") {
                        let b = draftBodies[.beginner] ?? ""
                        draftBodies[.senior] = b
                        draftBodies[.staff] = b
                    }
                    .buttonStyle(.bordered)
                    .disabled((draftBodies[.beginner] ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                    TextEditor(text: bodyBinding)
                        .font(.body)
                        .frame(minHeight: 220)
                        .padding(6)
                        .background(RoundedRectangle(cornerRadius: 6).fill(Color(nsColor: .textBackgroundColor)))
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .strokeBorder(Color(nsColor: .separatorColor), lineWidth: 1)
                        )
                        .promptZenActivateOnTap()
                }

                HStack {
                    Text("Est. tokens (\(selectedLevel.displayName))")
                    Spacer()
                    Text("\(TokenEstimator.estimateTokens(for: draftBodies[selectedLevel] ?? ""))")
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .navigationTitle("New Prompt")
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
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel", action: onCancel)
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    let t = title.trimmingCharacters(in: .whitespacesAndNewlines)
                    let m = LibraryTaxonomy.normalizeMain(mainCategory)
                    let s = LibraryTaxonomy.normalizeSub(subcategory)
                    let p = Prompt(
                        id: initial.id,
                        title: t,
                        bodies: draftBodies,
                        mainCategory: m,
                        subcategory: s,
                        isFavorite: false,
                        createdAt: initial.createdAt,
                        updatedAt: Date()
                    )
                    onSave(p)
                }
                .disabled(!canSave)
            }
        }
        .onAppear {
            PromptZenAppActivation.activateKeyWindowHierarchy()
            DispatchQueue.main.async {
                PromptZenAppActivation.activateKeyWindowHierarchy()
                titleFocused = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                PromptZenAppActivation.activateKeyWindowHierarchy()
            }
        }
    }

    private func labeledField<Content: View>(_ label: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.headline)
            content()
        }
    }
}
