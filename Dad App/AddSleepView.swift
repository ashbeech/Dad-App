//
//  AddSleepView.swift
//  Dad App
//
//  Created by Ashley Davison on 06/03/2025.
//

import SwiftUI

struct AddSleepView: View {
    @EnvironmentObject var dataStore: DataStore
    @Environment(\.presentationMode) var presentationMode
    
    let date: Date
    let initialTime: Date
    
    @State private var sleepType: SleepType = .nap // Only naps can be added manually
    @State private var startTime: Date
    @State private var endTime: Date
    @State private var notes: String = ""
    @State private var isTemplate: Bool = false
    @State private var showEndTime: Bool = false
    @State private var startImmediately: Bool = true
    
    init(date: Date, initialTime: Date = Date()) {
        self.date = date
        self.initialTime = initialTime
        
        // Initialize with the provided initialTime instead of just the date
        let calendar = Calendar.current
        
        // Extract year, month, day from date and hour, minute from initialTime
        var dateComponents = calendar.dateComponents([.year, .month, .day], from: date)
        let timeComponents = calendar.dateComponents([.hour, .minute], from: initialTime)
        
        // Combine them
        dateComponents.hour = timeComponents.hour
        dateComponents.minute = timeComponents.minute
        
        let combinedDate = calendar.date(from: dateComponents) ?? initialTime
        _startTime = State(initialValue: combinedDate)
        
        // Default end time is 30 mins after start time
        _endTime = State(initialValue: combinedDate.addingTimeInterval(30 * 60))
    }
    
    // Computed property to determine if save button should be disabled
    private var shouldDisableSaveButton: Bool {
        // Get all ongoing naps for today
        let ongoingNaps = dataStore.getOngoingSleepEvents(for: date).filter { $0.sleepType == .nap }
        
        // No ongoing naps means no restrictions
        if ongoingNaps.isEmpty {
            return false
        }
        
        // Check if the start time falls within any ongoing nap's time period
        for ongoingNap in ongoingNaps {
            let napEndTime = SleepUtilities.calculateEffectiveEndTime(sleepEvent: ongoingNap)
            
            if startTime >= ongoingNap.date && startTime <= napEndTime {
                // Start time overlaps with an ongoing nap
                
                // If user has specified an end time, allow saving
                if showEndTime {
                    return false
                }
                
                // If this would be another ongoing nap, disallow saving
                return startImmediately
            }
        }
        
        // If start time doesn't overlap with any ongoing nap, always allow saving
        return false
    }
    
    var body: some View {
        Form {
            Section(header: Text("Sleep Type")) {
                // Only allow adding naps, not wake or bedtime
                Text("Nap")
                    .font(.headline)
            }
            
            Section(header: Text("Timing")) {
                if showEndTime {
                    // Only show start time field if end time is being shown
                    DatePicker("Start Time", selection: $startTime, displayedComponents: .hourAndMinute)
                    
                    DatePicker("End Time", selection: $endTime, displayedComponents: .hourAndMinute)
                        .onChange(of: startTime) { _, newValue in
                            // Ensure end time is always after start time
                            if endTime <= newValue {
                                endTime = newValue.addingTimeInterval(30 * 60)
                            }
                        }
                    
                    // Add button to remove end time
                    Button(action: {
                        showEndTime = false
                        // Reset to "now" when end time is removed
                        startImmediately = true
                    }) {
                        HStack {
                            Image(systemName: "minus.circle.fill")
                                .foregroundColor(.red)
                            Text("Remove End Time")
                                .foregroundColor(.red)
                        }
                    }
                } else {
                    // When no end time, show "Start nap from now" instead of time picker
                    HStack {
                        Text("Start nap from now")
                            .foregroundColor(.primary)
                        Spacer()
                        Text("Current time")
                            .foregroundColor(.secondary)
                            .font(.subheadline)
                    }
                    
                    // Add button to add end time
                    Button(action: {
                        showEndTime = true
                        // Set end time to 30 minutes after current start time
                        endTime = startTime.addingTimeInterval(30 * 60)
                    }) {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                                .foregroundColor(.blue)
                            Text("+ End Time")
                                .foregroundColor(.blue)
                        }
                    }
                }
            }
            
            Section(header: Text("Notes")) {
                TextField("Any special notes", text: $notes)
            }
            
            Section {
                Toggle("Save as template", isOn: $isTemplate)
                    .toggleStyle(SwitchToggleStyle(tint: .blue))
                    .onChange(of: isTemplate) { _, newValue in
                        // If saving as template, always show end time option
                        if newValue {
                            showEndTime = true
                        }
                    }
            }
            
            // Warning message if save button is disabled
            if shouldDisableSaveButton {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                    Text("There's already an ongoing nap at this time")
                        .font(.caption)
                        .foregroundColor(.orange)
                }
                .padding(.horizontal)
            }
            
            Button(action: saveEvent) {
                Text("Save Nap")
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(shouldDisableSaveButton ? Color.gray : Color.purple)
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }
            .buttonStyle(PlainButtonStyle())
            .padding()
            .disabled(shouldDisableSaveButton)
        }
    }
    
    private func saveEvent() {
        // Create a placeholder end time that's 8 hours after start
        // This is just for the data model, but the nap will be treated as ongoing
        let placeholderEndTime = startTime.addingTimeInterval(8 * 3600) // 8 hours is a long nap
        
        // If not showing end time, use current time (now) as start time
        let effectiveStartTime = showEndTime ? startTime : Date()
        
        let sleepEvent = SleepEvent(
            date: effectiveStartTime,
            sleepType: .nap, // Only allow naps
            endTime: showEndTime ? endTime : placeholderEndTime, // Use actual end time only if specified
            notes: notes,
            isTemplate: false,
            isOngoing: !showEndTime && startImmediately, // Ongoing if no end time and starting now
            isPaused: false,
            pauseIntervals: [],
            lastPauseTime: nil
        )
        
        // Add event for the day
        dataStore.addSleepEvent(sleepEvent, for: date)
        
        // If it's a template, add it to the baby's templates
        if isTemplate {
            var updatedBaby = dataStore.baby
            updatedBaby.sleepTemplates.append(SleepEvent(
                date: startTime,
                sleepType: .nap,
                endTime: showEndTime ? endTime : startTime.addingTimeInterval(30 * 60),
                notes: notes,
                isTemplate: true
            ))
            
            dataStore.baby = updatedBaby
        }
        
        presentationMode.wrappedValue.dismiss()
    }
}
