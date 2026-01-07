//
//  PreferencesView.swift
//  Dad App
//
//  Phase 2: User preferences for AI task scheduling
//

import SwiftUI

struct PreferencesView: View {
    @EnvironmentObject var dataStore: DataStore
    @Environment(\.dismiss) var dismiss
    
    // Local state for editing (committed on save)
    @State private var availableHours: Double
    @State private var taskDuration: Int
    @State private var selectedTimeBlocks: Set<TimeBlock>
    @State private var selectedWorkDays: Set<Weekday>
    
    init() {
        // Initialize with defaults - will be overwritten in onAppear
        _availableHours = State(initialValue: 2.0)
        _taskDuration = State(initialValue: 30)
        _selectedTimeBlocks = State(initialValue: [.morning])
        _selectedWorkDays = State(initialValue: Set(Weekday.weekdays))
    }
    
    var body: some View {
        NavigationView {
            Form {
                // Available Hours Section
                Section {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Available hours per day")
                            Spacer()
                            Text(formatHours(availableHours))
                                .foregroundColor(.secondary)
                                .fontWeight(.medium)
                        }
                        
                        Slider(value: $availableHours, in: 0.5...8, step: 0.5)
                            .tint(.indigo)
                    }
                } header: {
                    Text("Daily Availability")
                } footer: {
                    Text("How much time can you dedicate to goal tasks each day?")
                }
                
                // Task Duration Section
                Section {
                    Picker("Preferred task length", selection: $taskDuration) {
                        Text("15 minutes").tag(15)
                        Text("30 minutes").tag(30)
                        Text("45 minutes").tag(45)
                        Text("60 minutes").tag(60)
                        Text("90 minutes").tag(90)
                    }
                    .pickerStyle(.menu)
                } header: {
                    Text("Task Size")
                } footer: {
                    Text("AI will try to break tasks into chunks of this size.")
                }
                
                // Time Blocks Section
                Section {
                    ForEach(TimeBlock.allCases, id: \.self) { block in
                        Toggle(isOn: Binding(
                            get: { selectedTimeBlocks.contains(block) },
                            set: { isSelected in
                                if isSelected {
                                    selectedTimeBlocks.insert(block)
                                } else if selectedTimeBlocks.count > 1 {
                                    // Prevent deselecting all
                                    selectedTimeBlocks.remove(block)
                                }
                            }
                        )) {
                            HStack {
                                Image(systemName: iconForTimeBlock(block))
                                    .foregroundColor(colorForTimeBlock(block))
                                    .frame(width: 24)
                                Text(block.displayName)
                            }
                        }
                        .tint(.indigo)
                    }
                } header: {
                    Text("Preferred Times")
                } footer: {
                    Text("When do you prefer to work on goal tasks?")
                }
                
                // Work Days Section
                Section {
                    LazyVGrid(columns: [
                        GridItem(.flexible()),
                        GridItem(.flexible()),
                        GridItem(.flexible()),
                        GridItem(.flexible())
                    ], spacing: 12) {
                        ForEach(Weekday.allCases, id: \.self) { day in
                            DayToggleButton(
                                day: day,
                                isSelected: selectedWorkDays.contains(day),
                                action: {
                                    if selectedWorkDays.contains(day) {
                                        if selectedWorkDays.count > 1 {
                                            selectedWorkDays.remove(day)
                                        }
                                    } else {
                                        selectedWorkDays.insert(day)
                                    }
                                }
                            )
                        }
                    }
                    .padding(.vertical, 8)
                } header: {
                    Text("Work Days")
                } footer: {
                    Text("Which days do you work on your goals?")
                }
                
                // Summary Section
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Your Schedule")
                            .font(.headline)
                        
                        let tasksPerDay = Int(availableHours * 60) / taskDuration
                        Text("Up to **\(tasksPerDay) tasks** per day")
                        Text("**\(selectedWorkDays.count) days** per week")
                        Text("**\(formatHours(availableHours * Double(selectedWorkDays.count)))** total weekly")
                    }
                    .foregroundColor(.secondary)
                    .font(.subheadline)
                }
            }
            .navigationTitle("Preferences")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        savePreferences()
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
            .onAppear {
                loadCurrentPreferences()
            }
        }
    }
    
    private func loadCurrentPreferences() {
        let prefs = dataStore.userPreferences
        availableHours = prefs.availableHoursPerDay
        taskDuration = prefs.preferredTaskDurationMinutes
        selectedTimeBlocks = Set(prefs.preferredTimeBlocks)
        selectedWorkDays = Set(prefs.workDays)
    }
    
    private func savePreferences() {
        dataStore.userPreferences = UserPreferences(
            availableHoursPerDay: availableHours,
            preferredTaskDurationMinutes: taskDuration,
            preferredTimeBlocks: Array(selectedTimeBlocks).sorted { $0.rawValue < $1.rawValue },
            workDays: Array(selectedWorkDays).sorted { 
                Weekday.allCases.firstIndex(of: $0)! < Weekday.allCases.firstIndex(of: $1)!
            }
        )
        
        // Haptic feedback
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
    }
    
    private func formatHours(_ hours: Double) -> String {
        if hours == Double(Int(hours)) {
            return "\(Int(hours)) hr\(hours == 1 ? "" : "s")"
        } else {
            let h = Int(hours)
            let m = Int((hours - Double(h)) * 60)
            if h == 0 {
                return "\(m) min"
            }
            return "\(h)h \(m)m"
        }
    }
    
    private func iconForTimeBlock(_ block: TimeBlock) -> String {
        switch block {
        case .morning: return "sunrise.fill"
        case .afternoon: return "sun.max.fill"
        case .evening: return "sunset.fill"
        }
    }
    
    private func colorForTimeBlock(_ block: TimeBlock) -> Color {
        switch block {
        case .morning: return .orange
        case .afternoon: return .yellow
        case .evening: return .purple
        }
    }
}

// MARK: - Day Toggle Button

struct DayToggleButton: View {
    let day: Weekday
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(String(day.displayName.prefix(3)))
                .font(.subheadline)
                .fontWeight(isSelected ? .semibold : .regular)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(isSelected ? Color.indigo : Color.gray.opacity(0.2))
                .foregroundColor(isSelected ? .white : .primary)
                .cornerRadius(8)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Preview

#Preview {
    PreferencesView()
        .environmentObject(DataStore())
}

