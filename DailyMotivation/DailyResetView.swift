import SwiftUI

struct DailyResetView: View {
    @ObservedObject var manager: DailyResetManager
    @ObservedObject var viewModel: QuoteViewModel
    @ObservedObject var engagementTracker: EngagementTracker
    let preferredCategories: [String]

    @Environment(\.dismiss) private var dismiss
    @State private var activeEntryID: UUID?
    @State private var selectedNeed: DailyNeed?
    @State private var reflection = ""
    @State private var selectedAction = ""

    private var activeEntry: DailyResetEntry? {
        guard let activeEntryID else { return manager.entry() }
        return manager.entries.first { $0.id == activeEntryID }
    }

    private var activeQuote: Quote? {
        guard let quoteID = activeEntry?.quoteID else { return nil }
        return viewModel.allQuotes.first { $0.id == quoteID }
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
            .navigationTitle("Daily Reset")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .onAppear(perform: loadExistingEntry)
        }
    }

    private var needPicker: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text("What do you need right now?")
                    .font(.title2.bold())

                LazyVGrid(
                    columns: [GridItem(.flexible()), GridItem(.flexible())],
                    spacing: 12
                ) {
                    ForEach(DailyNeed.allCases) { need in
                        Button {
                            beginReset(for: need)
                        } label: {
                            VStack(spacing: 10) {
                                Image(systemName: need.iconName)
                                    .font(.title2)
                                Text(need.displayName)
                                    .font(.headline)
                            }
                            .frame(maxWidth: .infinity, minHeight: 92)
                            .foregroundStyle(.primary)
                            .background(Color(.secondarySystemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
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
                    Label("Today's reset is complete", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                }
            }

            Section("Today's quote") {
                if let quote = activeQuote {
                    Text("\"\(quote.quote)\"")
                        .font(.headline)
                    Text("- \(quote.author)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Label(need.displayName, systemImage: need.iconName)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }

            Section {
                TextEditor(text: $reflection)
                    .frame(minHeight: 130)
                    .onChange(of: reflection) { newValue in
                        manager.update(entryID: entry.id, reflection: newValue)
                    }
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
                    .frame(maxWidth: .infinity)
                }
                .disabled(
                    entry.isCompleted ||
                    reflection.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                    selectedAction.isEmpty
                )
            }
        }
    }

    private func beginReset(for need: DailyNeed) {
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
        viewModel.currentQuote = quote
        activeEntryID = entry.id
        selectedNeed = need
        reflection = entry.reflection
        selectedAction = entry.action
    }

    private func loadExistingEntry() {
        guard let entry = manager.entry() else { return }
        activeEntryID = entry.id
        selectedNeed = entry.need
        reflection = entry.reflection
        selectedAction = entry.action
        if let quote = viewModel.allQuotes.first(where: { $0.id == entry.quoteID }) {
            viewModel.currentQuote = quote
        }
    }

    private func complete(entry: DailyResetEntry) {
        manager.update(
            entryID: entry.id,
            reflection: reflection,
            action: selectedAction
        )
        if manager.complete(entryID: entry.id) {
            engagementTracker.logDailyResetCompleted(on: entry.date)
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
        .navigationTitle("Reflections")
    }
}
