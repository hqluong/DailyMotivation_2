import SwiftUI

struct DailyResetView: View {
    @ObservedObject var manager: DailyResetManager
    @ObservedObject var viewModel: QuoteViewModel
    @ObservedObject var engagementTracker: EngagementTracker
    let preferredCategories: [String]

    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @State private var activeEntryID: UUID?
    @State private var selectedNeed: DailyNeed?
    @State private var reflection = ""
    @State private var selectedAction = ""
    @State private var showCompletionCelebration = false
    @FocusState private var isReflectionFocused: Bool

    private var activeEntry: DailyResetEntry? {
        guard let activeEntryID else { return manager.entry() }
        return manager.entries.first { $0.id == activeEntryID }
    }

    private var activeQuote: Quote? {
        guard let quoteID = activeEntry?.quoteID else { return nil }
        return viewModel.allQuotes.first { $0.id == quoteID }
    }

    private var canComplete: Bool {
        !reflection.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !selectedAction.isEmpty
    }

    var body: some View {
        NavigationStack {
            Group {
                if let entry = activeEntry {
                    resetForm(entry: entry, need: selectedNeed ?? entry.need)
                } else {
                    needPicker
                }
            }
            .themedScreen()
            .navigationTitle("Daily Reset")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        saveReflection()
                        dismiss()
                    }
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") { isReflectionFocused = false }
                }
            }
            .onAppear(perform: loadExistingEntry)
            .onDisappear(perform: saveReflection)
            .onChange(of: scenePhase) { phase in
                if phase != .active { saveReflection() }
            }
        }
    }

    private var needPicker: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("What do you need right now?")
                        .font(.title2.bold())
                    Text("Pick one, write a sentence, and choose a small action. It takes about a minute and keeps your streak going.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                LazyVGrid(
                    columns: [GridItem(.flexible()), GridItem(.flexible())],
                    spacing: 12
                ) {
                    ForEach(DailyNeed.allCases) { need in
                        Button {
                            beginReset(for: need, carryingReflection: reflection)
                        } label: {
                            VStack(spacing: 10) {
                                Image(systemName: need.iconName)
                                    .font(.title2)
                                    .foregroundStyle(.tint)
                                Text(need.displayName)
                                    .font(.headline)
                                    .foregroundStyle(.primary)
                            }
                            .frame(maxWidth: .infinity, minHeight: 92)
                            .background(Color(.secondarySystemGroupedBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                            .shadow(color: Color.black.opacity(0.06), radius: 6, x: 0, y: 3)
                        }
                        .buttonStyle(.plain)
                        .accessibilityHint("Starts today's reflection with a relevant quote")
                    }
                }
            }
            .padding()
        }
    }

    private func resetForm(entry: DailyResetEntry, need: DailyNeed) -> some View {
        Form {
            if entry.isCompleted {
                Section {
                    VStack(alignment: .leading, spacing: 6) {
                        Label("Today's reset is complete", systemImage: "checkmark.circle.fill")
                            .font(.headline)
                            .foregroundStyle(.green)
                        let streak = engagementTracker.summary.currentStreak
                        Text(streak == 1 ? "🔥 1-day streak. Come back tomorrow to keep it going." : "🔥 \(streak)-day streak. Nice work.")
                            .font(.subheadline)
                    }
                    .padding(.vertical, 4)
                    .scaleEffect(showCompletionCelebration ? 1.03 : 1)
                    .animation(.spring(response: 0.35, dampingFraction: 0.6), value: showCompletionCelebration)
                    .accessibilityElement(children: .combine)
                }
            }

            Section("Your quote for this reset") {
                if let quote = activeQuote {
                    Text("\"\(quote.quote)\"")
                        .font(.headline)
                    Text("- \(quote.author)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                HStack {
                    Label(need.displayName, systemImage: need.iconName)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Spacer()
                    if !entry.isCompleted {
                        Button("Change need") {
                            changeNeed(entry: entry)
                        }
                        .font(.caption.weight(.semibold))
                        .buttonStyle(.borderless)
                    }
                }
            }

            Section {
                TextEditor(text: $reflection)
                    .frame(minHeight: 130)
                    .focused($isReflectionFocused)
                    .overlay(alignment: .topLeading) {
                        if reflection.isEmpty {
                            Text("Write a sentence or two…")
                                .foregroundStyle(.tertiary)
                                .padding(.top, 8)
                                .padding(.leading, 5)
                                .allowsHitTesting(false)
                        }
                    }
                    // Saved on Done, completion, need change, or backgrounding; saving per keystroke
                    // republishes the manager and drops the editor's focus mid-typing.
            } header: {
                Text(need.reflectionPrompt)
            }

            Section("One small action") {
                Picker("Action", selection: $selectedAction) {
                    ForEach(need.suggestedActions, id: \.self) { action in
                        Text(action).tag(action)
                    }
                }
                .pickerStyle(.inline)
                .labelsHidden()
                .onChange(of: selectedAction) { newValue in
                    manager.update(entryID: entry.id, action: newValue)
                }
            }

            Section {
                Button {
                    complete(entry: entry)
                } label: {
                    Label(
                        entry.isCompleted ? "Reset completed" : "Complete today's reset",
                        systemImage: entry.isCompleted ? "checkmark.circle.fill" : "checkmark.circle"
                    )
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(.borderedProminent)
                .tint(.green)
                .disabled(entry.isCompleted || !canComplete)
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
            } footer: {
                if !entry.isCompleted && !canComplete {
                    Text("Write a short reflection above to complete today's reset.")
                }
            }
        }
        .scrollDismissesKeyboard(.interactively)
    }

    private func beginReset(for need: DailyNeed, carryingReflection carried: String = "") {
        var categories = need.quoteCategories
        for category in preferredCategories where !categories.contains(category) {
            categories.append(category)
        }

        let exclusions = viewModel.currentQuote.map { Set([$0.id]) } ?? []
        guard let quote = viewModel.preferredRandomQuote(
            preferredCategories: categories,
            excludingIDs: exclusions
        ) else {
            return
        }

        let action = need.suggestedActions[0]
        let entry = manager.start(need: need, quoteID: quote.id, action: action)
        if !carried.isEmpty {
            manager.update(entryID: entry.id, reflection: carried)
        }
        activeEntryID = entry.id
        selectedNeed = need
        reflection = carried.isEmpty ? entry.reflection : carried
        selectedAction = entry.action
    }

    /// Lets the user pick a different need before completing, keeping anything already written.
    private func changeNeed(entry: DailyResetEntry) {
        guard !entry.isCompleted else { return }
        let carried = reflection
        isReflectionFocused = false
        manager.remove(entryID: entry.id)
        activeEntryID = nil
        selectedNeed = nil
        selectedAction = ""
        reflection = carried
    }

    private func loadExistingEntry() {
        guard let entry = manager.entry() else { return }
        activeEntryID = entry.id
        selectedNeed = entry.need
        reflection = entry.reflection
        selectedAction = entry.action
    }

    private func saveReflection() {
        guard let entry = activeEntry, !entry.isCompleted else { return }
        manager.update(entryID: entry.id, reflection: reflection)
    }

    private func complete(entry: DailyResetEntry) {
        isReflectionFocused = false
        manager.update(
            entryID: entry.id,
            reflection: reflection,
            action: selectedAction
        )
        if manager.complete(entryID: entry.id) {
            engagementTracker.logDailyResetCompleted(on: entry.date)
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            showCompletionCelebration = true
        }
    }
}

struct ReflectionLibraryView: View {
    @ObservedObject var resetManager: DailyResetManager
    @ObservedObject var noteManager: NoteManager
    let quotes: [Quote]

    private var quoteByID: [UUID: Quote] {
        Dictionary(uniqueKeysWithValues: quotes.map { ($0.id, $0) })
    }

    private var noteIDs: [UUID] {
        noteManager.notes.keys.sorted {
            (quoteByID[$0]?.quote ?? "") < (quoteByID[$1]?.quote ?? "")
        }
    }

    var body: some View {
        List {
            if resetManager.entries.isEmpty && noteIDs.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Label("No reflections yet", systemImage: "text.book.closed")
                        .font(.headline)
                    Text("Complete a Daily Reset or add a note to a quote.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 8)
            }

            if !resetManager.entries.isEmpty {
                Section("Daily resets") {
                    ForEach(resetManager.entries) { entry in
                        VStack(alignment: .leading, spacing: 7) {
                            HStack {
                                Label(entry.need.displayName, systemImage: entry.need.iconName)
                                    .font(.headline)
                                Spacer()
                                Text(entry.date, format: .dateTime.month(.abbreviated).day())
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Text(entry.reflection)
                                .font(.body)
                            Label(entry.action, systemImage: "checkmark.circle")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            if let quote = quoteByID[entry.quoteID] {
                                Text("\"\(quote.quote)\"")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(2)
                            }
                        }
                        .padding(.vertical, 4)
                        .swipeActions {
                            Button(role: .destructive) {
                                resetManager.remove(entryID: entry.id)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                }
            }

            if !noteIDs.isEmpty {
                Section("Quote notes") {
                    ForEach(noteIDs, id: \.self) { quoteID in
                        if let quote = quoteByID[quoteID], let note = noteManager.notes[quoteID] {
                            VStack(alignment: .leading, spacing: 6) {
                                Text(note)
                                    .font(.body)
                                Text("\"\(quote.quote)\"")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(2)
                            }
                            .padding(.vertical, 4)
                            .swipeActions {
                                Button(role: .destructive) {
                                    noteManager.setNote("", for: quote)
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                        }
                    }
                }
            }
        }
        .themedScreen()
        .navigationTitle("Reflections")
    }
}
