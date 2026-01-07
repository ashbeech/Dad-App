//
//  EditSleepView.swift
//  Dad App
//
//  Created by Ash Beech on 06/03/2025.
//

import SwiftUI

struct EditSleepView: View {
    @EnvironmentObject var dataStore: DataStore
    @Environment(\.presentationMode) var presentationMode
    
    let sleepEvent: SleepEvent
    let date: Date
    
    @State private var sleepType: SleepType
    @State private var startTime: Date
    @State private var endTime: Date
    @State private var isOngoing: Bool
    @State private var isPaused: Bool
    @State private var pauseIntervals: [PauseInterval]
    @State private var lastPauseTime: Date?
    @State private var showDeleteConfirmation: Bool = false
    @State private var showSaveAsPermanentAlert: Bool = false
    
    init(sleepEvent: SleepEvent, date: Date) {
        self.sleepEvent = sleepEvent
        self.date = date
        
        _sleepType = State(initialValue: sleepEvent.sleepType)
        _startTime = State(initialValue: sleepEvent.date)
        _endTime = State(initialValue: sleepEvent.endTime)
        _isOngoing = State(initialValue: sleepEvent.isOngoing)
        _isPaused = State(initialValue: sleepEvent.isPaused)
        _pauseIntervals = State(initialValue: sleepEvent.pauseIntervals)
        _lastPauseTime = State(initialValue: sleepEvent.lastPauseTime)
    }
    
    var body: some View {
        Form {
            // For wake and bedtime events, don't allow changing the type
            if sleepEvent.sleepType == .waketime || sleepEvent.sleepType == .bedtime {
                Section(header: Text("Sleep Type")) {
                    HStack {
                        Text(sleepEvent.sleepType == .waketime ? "Wake Up Time" : "Bedtime")
                        Spacer()
                        Image(systemName: sleepEvent.sleepType == .waketime ? "sun.max.fill" : "bed.double.fill")
                            .foregroundColor(sleepEvent.sleepType == .waketime ? .orange : .blue)
                    }
                }
            }
            
            Section(header: Text("Timing")) {
                DatePicker("Start Time", selection: $startTime, displayedComponents: .hourAndMinute)
                
                // Only show end time for nap events (not waketime or bedtime)
                if sleepEvent.sleepType == .nap {
                    DatePicker("End Time", selection: $endTime, displayedComponents: .hourAndMinute)
                        .onChange(of: startTime) { _, newValue in
                            // Ensure end time is always after start time
                            if endTime <= newValue {
                                endTime = newValue.addingTimeInterval(30 * 60)
                            }
                        }
                }
            }
            
            // Only show tracking controls for nap events
            if sleepEvent.sleepType == .nap {
                // Add actual sleep duration display for naps
                if let actualDuration = sleepEvent.actualSleepDuration {
                    Section(header: Text("Actual Sleep Time")) {
                        HStack {
                            Image(systemName: "clock.fill")
                                .foregroundColor(.purple)
                            Text(formatDuration(actualDuration))
                                .foregroundColor(.primary)
                            Spacer()
                            if sleepEvent.isOngoing {
                                Text("(Live)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
                
                Section(header: Text("Tracking")) {
                    Toggle("Track in real-time", isOn: $isOngoing)
                        .toggleStyle(SwitchToggleStyle(tint: .purple))
                    
                    if isOngoing {
                        Toggle("Pause tracking", isOn: $isPaused)
                            .toggleStyle(SwitchToggleStyle(tint: .orange))
                            .onChange(of: isPaused) { _, newValue in
                                if newValue {
                                    // Pausing - record pause time
                                    lastPauseTime = Date()
                                } else {
                                    // Resuming - add pause interval
                                    if let pauseTime = lastPauseTime {
                                        pauseIntervals.append(PauseInterval(
                                            pauseTime: pauseTime,
                                            resumeTime: Date()
                                        ))
                                        lastPauseTime = nil
                                    }
                                }
                            }
                    }
                }
            }
            
            if sleepEvent.sleepType == .waketime || sleepEvent.sleepType == .bedtime {
                Section {
                    Button(action: {
                        showSaveAsPermanentAlert = true
                    }) {
                        Text("Save as permanent default time")
                            .foregroundColor(.blue)
                    }
                }
            }
            
            HStack {
                Button(action: saveEvent) {
                    Text("Update")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.purple)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
                .buttonStyle(PlainButtonStyle())
                
                // Only allow regular sleep events to be deleted, not wake or bedtime
                if sleepEvent.sleepType != .waketime && sleepEvent.sleepType != .bedtime {
                    Button(action: {
                        deleteEvent()
                        //showDeleteConfirmation = true
                    }) {
                        Text("Delete")
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.red)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding()
        }
        .alert(isPresented: $showSaveAsPermanentAlert) {
            Alert(
                title: Text("Save Default Time"),
                message: Text("Do you want to save this as the permanent default \(sleepEvent.sleepType == .waketime ? "wake" : "bedtime") for all days?"),
                primaryButton: .default(Text("Save")) {
                    savePermanentDefaultTime()
                },
                secondaryButton: .cancel()
            )
        }
    }
    
    private func saveEvent() {
                
        // For wake time, end time is not really relevant
        let finalEndTime: Date
        
        if sleepEvent.sleepType == .waketime {
            finalEndTime = startTime.addingTimeInterval(30 * 60)
        }
        else if sleepEvent.sleepType == .bedtime {
            // For bedtime, ensure the end time is the next day's wake time
            let calendar = Calendar.current
            var nextDay = calendar.dateComponents([.year, .month, .day], from: date)
            nextDay.day = (nextDay.day ?? 0) + 1
            
            // Use the current wake up time from Baby settings
            let wakeComponents = calendar.dateComponents([.hour, .minute], from: dataStore.baby.wakeTime)
            
            var nextWakeComponents = nextDay
            nextWakeComponents.hour = wakeComponents.hour
            nextWakeComponents.minute = wakeComponents.minute
            
            finalEndTime = calendar.date(from: nextWakeComponents) ?? startTime.addingTimeInterval(10 * 3600)
        }
        else {
            finalEndTime = endTime
        }
        
        let updatedEvent = SleepEvent(
            id: sleepEvent.id,
            date: startTime,
            sleepType: sleepEvent.sleepType,
            endTime: finalEndTime,
            notes: "",
            isTemplate: false,
            isOngoing: isOngoing,
            isPaused: isPaused,
            pauseIntervals: pauseIntervals,
            lastPauseTime: lastPauseTime,
            actualSleepDuration: sleepEvent.actualSleepDuration
        )
        
        dataStore.updateSleepEvent(updatedEvent, for: date)
        presentationMode.wrappedValue.dismiss()
    }
    
    private func deleteEvent() {
        // Log deletion attempt
        print("Attempting to delete sleep event: \(sleepEvent.id)")
        
        // Cancel any associated notifications
        NotificationManager.shared.cancelNotification(for: sleepEvent.id)
        
        // Delete from data store
        dataStore.deleteSleepEvent(sleepEvent, for: date)
        
        // Provide haptic feedback for deletion
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
        
        // For ongoing events, post a notification so other views can clear their state
        if sleepEvent.isOngoing {
            NotificationCenter.default.post(
                name: NSNotification.Name("ClearActiveNap"),
                object: sleepEvent.id
            )
        }
        
        // First dismiss this view
        presentationMode.wrappedValue.dismiss()
        
        // Then notify parent views to dismiss as well (same as in EditFeedView)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            NotificationCenter.default.post(name: NSNotification.Name("DismissEditView"), object: nil)
        }
    }
    
    private func savePermanentDefaultTime() {
                
        var updatedBaby = dataStore.baby
        
        if sleepEvent.sleepType == .waketime {
            // Update the Baby's default wake time
            updatedBaby.wakeTime = startTime
        } else if sleepEvent.sleepType == .bedtime {
            // Update the Baby's default bedtime
            updatedBaby.bedTime = startTime
        }
        
        dataStore.baby = updatedBaby
        
        // Save the event first
        saveEvent()

    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let hours = Int(duration) / 3600
        let minutes = (Int(duration) % 3600) / 60
        let seconds = Int(duration) % 60
        
        if hours > 0 {
            return String(format: "%dh %dm %ds", hours, minutes, seconds)
        } else {
            return String(format: "%dm %ds", minutes, seconds)
        }
    }
}
