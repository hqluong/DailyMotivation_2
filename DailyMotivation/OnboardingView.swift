// MARK: - OnboardingView.swift

import SwiftUI

/// The data returned when onboarding finishes.
struct OnboardingResult {
    let primaryCategory: String?
    let reminderEnabled: Bool
    let reminderHour: Int
    let reminderMinute: Int
}

/// A lightweight onboarding flow that helps users pick content and reminders.
struct OnboardingView: View {
    let categories: [String]
    let defaultCategory: String
    let onComplete: (OnboardingResult) -> Void

    @State private var selectedCategories: Set<String>
    @State private var reminderEnabled: Bool
    @State private var reminderTime: Date

    init(
        categories: [String],
        defaultCategory: String,
        defaultReminderHour: Int,
        defaultReminderMinute: Int,
        onComplete: @escaping (OnboardingResult) -> Void
    ) {
        self.categories = categories
        self.defaultCategory = defaultCategory
        self.onComplete = onComplete
        _selectedCategories = State(initialValue: Set([defaultCategory]))
        _reminderEnabled = State(initialValue: true)
        _reminderTime = State(initialValue: Self.makeDate(hour: defaultReminderHour, minute: defaultReminderMinute))
    }

    var body: some View {
        ZStack {
            // Liquid glass background with layered blurs
            LinearGradient(
                colors: [
                    Color(red: 0.10, green: 0.12, blue: 0.22),
                    Color(red: 0.06, green: 0.09, blue: 0.18),
                    Color(red: 0.09, green: 0.18, blue: 0.32)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            ZStack {
                Circle()
                    .fill(Color(red: 1.0, green: 0.35, blue: 0.55).opacity(0.22))
                    .frame(width: 260, height: 260)
                    .offset(x: -140, y: -260)
                    .blur(radius: 48)
                Circle()
                    .fill(Color(red: 0.28, green: 0.65, blue: 0.98).opacity(0.18))
                    .frame(width: 280, height: 280)
                    .offset(x: 180, y: -120)
                    .blur(radius: 52)
                Circle()
                    .fill(Color(red: 0.38, green: 0.85, blue: 0.65).opacity(0.14))
                    .frame(width: 320, height: 320)
                    .offset(x: 80, y: 260)
                    .blur(radius: 56)
            }
            .ignoresSafeArea()

            VStack(spacing: 24) {
                VStack(spacing: 8) {
                    Text("Welcome to Daily Motivation")
                        .font(.largeTitle).bold()
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                    Text("Pick what inspires you, set a reminder, and start a streak.")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.82))
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 20)

                glassCard {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Choose your focus")
                            .font(.headline)
                            .foregroundColor(.white)
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 2), spacing: 10) {
                            ForEach(categories, id: \.self) { category in
                                let isSelected = selectedCategories.contains(category)
                                Button {
                                    toggle(category: category)
                                } label: {
                                    HStack {
                                        Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                                            .foregroundStyle(isSelected ? Color.green : Color.white.opacity(0.7))
                                        Text(category)
                                            .foregroundColor(.white)
                                            .font(.subheadline)
                                        Spacer()
                                    }
                                    .padding()
                                    .background(.ultraThinMaterial)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                                            .stroke(
                                                LinearGradient(
                                                    colors: [
                                                        Color.white.opacity(0.18),
                                                        Color.white.opacity(0.06)
                                                    ],
                                                    startPoint: .topLeading,
                                                    endPoint: .bottomTrailing
                                                ),
                                                lineWidth: 1
                                            )
                                    )
                                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                                }
                            }
                        }
                    }
                }

                glassCard {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Daily reminder")
                            .font(.headline)
                            .foregroundColor(.white)

                        Toggle(isOn: $reminderEnabled) {
                            Text("Send me a daily quote")
                                .foregroundColor(.white)
                        }
                        .tint(.green)

                        DatePicker(
                            "Reminder time",
                            selection: $reminderTime,
                            displayedComponents: .hourAndMinute
                        )
                        .disabled(!reminderEnabled)
                        .foregroundColor(.white)
                        .colorMultiply(.white)
                    }
                }

                glassCard {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Tips")
                            .font(.headline)
                            .foregroundColor(.white)
                        tipRow(icon: "heart.fill", text: "Tap the heart to favorite and fill your library.")
                        tipRow(icon: "square.and.arrow.up", text: "Share quotes with friends in two taps.")
                        tipRow(icon: "flame.fill", text: "Keep your streak going by reading and favoriting daily.")
                    }
                }

                Spacer()

                Button(action: finish) {
                    Text("Start my day")
                        .font(.headline)
                        .foregroundColor(.black.opacity(0.9))
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(.thinMaterial)
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .stroke(
                                    LinearGradient(
                                        colors: [
                                            Color.white.opacity(0.45),
                                            Color.white.opacity(0.2)
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 1.2
                                )
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .shadow(color: Color.black.opacity(0.2), radius: 16, x: 0, y: 10)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 24)
            }
        }
    }

    private func finish() {
        let comps = Calendar.current.dateComponents([.hour, .minute], from: reminderTime)
        let result = OnboardingResult(
            primaryCategory: selectedCategories.first ?? defaultCategory,
            reminderEnabled: reminderEnabled,
            reminderHour: comps.hour ?? 9,
            reminderMinute: comps.minute ?? 0
        )
        onComplete(result)
    }

    private func toggle(category: String) {
        if selectedCategories.contains(category) && selectedCategories.count > 1 {
            selectedCategories.remove(category)
        } else {
            selectedCategories.insert(category)
        }
    }

    @ViewBuilder
    private func tipRow(icon: String, text: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .foregroundColor(.white)
            Text(text)
                .foregroundColor(.white.opacity(0.9))
                .font(.subheadline)
            Spacer()
        }
    }

    @ViewBuilder
    private func glassCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.ultraThinMaterial)
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.35),
                                Color.white.opacity(0.12)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            )
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .shadow(color: Color.black.opacity(0.16), radius: 18, x: 0, y: 10)
            .padding(.horizontal, 20)
    }

    private static func makeDate(hour: Int, minute: Int) -> Date {
        var comps = DateComponents()
        comps.hour = hour
        comps.minute = minute
        return Calendar.current.date(from: comps) ?? Date()
    }
}
