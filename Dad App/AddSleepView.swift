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
    
    // New state for tracking overlap info
    @State private var overlappingNap: SleepEvent? = nil
    @State private var hasCheckedForOverlap: Bool = false
    
    init(date: Date, initialTime: Date = Date()) {
        self.date = date
        self.initialTime = initialTime
        
        // Initialize with the provided initialTime
        let calendar = Calendar.current
        
        // Extract year, month, day from date and hour, minute from initialTime
        var dateComponents = calendar.dateComponents([.year, .month, .day], from: date)
        let timeComponents = calendar.dateComponents([.hour, .minute, .second], from: initialTime)
        
        // Combine them
        dateComponents.hour = timeComponents.hour
        dateComponents.minute = timeComponents.minute
        dateComponents.second = timeComponents.second
        
        let combinedDate = calendar.date(from: dateComponents) ?? initialTime
        
        // Debug logging
        //print("AddSleepView initializing with time: \(formatTime(combinedDate))")
        
        _startTime = State(initialValue: combinedDate)
        
        // Default end time is 30 mins after start time
        _endTime = State(initialValue: combinedDate.addingTimeInterval(30 * 60))
    }
    
    // Computed property to determine if save button should be disabled
    private var shouldDisableSaveButton: Bool {
        if !hasCheckedForOverlap {
            checkForOverlappingNaps()
        }
        return overlappingNap != nil
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
                        .onChange(of: startTime) { _, newValue in
                            checkForOverlappingNaps()
                        }
                    
                    DatePicker("End Time", selection: $endTime, displayedComponents: .hourAndMinute)
                        .onChange(of: endTime) { _, newValue in
                            // Ensure end time is always after start time
                            if endTime <= startTime {
                                endTime = startTime.addingTimeInterval(30 * 60)
                            }
                            checkForOverlappingNaps()
                        }
                    
                    // Add button to remove end time
                    Button(action: {
                        showEndTime = false
                        // Reset to "now" when end time is removed
                        startImmediately = true
                        checkForOverlappingNaps()
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
                    .onAppear {
                        checkForOverlappingNaps()
                    }
                    
                    // Add button to add end time
                    Button(action: {
                        showEndTime = true
                        // Set end time to 30 minutes after current start time
                        endTime = startTime.addingTimeInterval(30 * 60)
                        checkForOverlappingNaps()
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
                            checkForOverlappingNaps()
                        }
                    }
            }
            
            // Warning message if save button is disabled due to overlap
            if let overlap = overlappingNap {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                        Text("Time Conflict Detected")
                            .font(.headline)
                            .foregroundColor(.orange)
                    }
                    
                    Text("This nap would overlap with an existing nap:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    HStack {
                        Text(formatTime(overlap.date))
                        Text("-")
                        if overlap.isOngoing {
                            Text("ongoing")
                                .italic()
                        } else {
                            Text(formatTime(overlap.endTime))
                        }
                    }
                    .font(.caption)
                    .padding(6)
                    .background(Color.purple.opacity(0.1))
                    .cornerRadius(6)
                    
                    Text("Please choose a different time or adjust the existing nap.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 8)
                .background(Color.orange.opacity(0.1))
                .cornerRadius(8)
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
        .onAppear {
            checkForOverlappingNaps()
        }
    }
    
    private func checkForOverlappingNaps() {
        hasCheckedForOverlap = true
        
        // Function to check if two time ranges overlap
        func timeRangesOverlap(start1: Date, end1: Date, start2: Date, end2: Date) -> Bool {
            return start1 < end2 && start2 < end1
        }
        
        // Get the effective time range for this new nap
        let effectiveStartTime = showEndTime ? startTime : Date()
        let effectiveEndTime = showEndTime ? endTime : effectiveStartTime.addingTimeInterval(30 * 60)
        
        // Get all naps for the day
        let dateString = dataStore.formatDate(date)
        let sleepEvents = dataStore.sleepEvents[dateString] ?? []
        
        // Check for any overlapping naps
        for napEvent in sleepEvents.filter({ $0.sleepType == .nap }) {
            // For ongoing naps, use current time as the effective end time
            let napEndTime = napEvent.isOngoing ?
                (napEvent.isPaused ? (napEvent.lastPauseTime ?? Date()) : Date()) :
                napEvent.endTime
            
            if timeRangesOverlap(
                start1: effectiveStartTime,
                end1: effectiveEndTime,
                start2: napEvent.date,
                end2: napEndTime
            ) {
                overlappingNap = napEvent
                return
            }
        }
        
        // No overlap found
        overlappingNap = nil
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    private func saveEvent() {
        // One final check for overlaps
        checkForOverlappingNaps()
        if overlappingNap != nil {
            return // Don't save if there's an overlap
        }
        
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
        
        // Provide haptic feedback for successful save
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
        
        presentationMode.wrappedValue.dismiss()
    }
}
