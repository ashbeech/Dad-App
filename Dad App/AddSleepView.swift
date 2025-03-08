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
    
    @State private var sleepType: SleepType = .nap // Only naps can be added manually
    @State private var startTime: Date
    @State private var endTime: Date
    @State private var notes: String = ""
    @State private var isTemplate: Bool = false
    @State private var includeEndTime: Bool = false
    @State private var startImmediately: Bool = true
    
    init(date: Date) {
        self.date = date
        
        // Initialize with the passed date
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: date)
        let minute = calendar.component(.minute, from: date)
        
        var components = calendar.dateComponents([.year, .month, .day], from: date)
        components.hour = hour
        components.minute = minute
        
        let initialDate = calendar.date(from: components) ?? date
        _startTime = State(initialValue: initialDate)
        
        // Default end time is 30 mins after start time
        _endTime = State(initialValue: initialDate.addingTimeInterval(30 * 60))
    }
    
    var body: some View {
        Form {
            Section(header: Text("Sleep Type")) {
                // Only allow adding naps, not wake or bedtime
                Text("Nap")
                    .font(.headline)
            }
            
            Section(header: Text("Timing")) {
                DatePicker("Start Time", selection: $startTime, displayedComponents: .hourAndMinute)
                DatePicker("End Time", selection: $endTime, displayedComponents: .hourAndMinute)
                    .onChange(of: startTime) { _, newValue in
                        // Ensure end time is always after start time
                        if endTime <= newValue {
                            endTime = newValue.addingTimeInterval(30 * 60)
                        }
                    }
            }
            
            Section(header: Text("Notes")) {
                TextField("Any special notes", text: $notes)
            }
            
            Section {
                Toggle("Save as template", isOn: $isTemplate)
                    .toggleStyle(SwitchToggleStyle(tint: .blue))
            }
            
            Button(action: saveEvent) {
                Text("Save Nap")
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.purple)
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }
            .buttonStyle(PlainButtonStyle())
            .padding()
        }
    }
    
    private func saveEvent() {
        // Create the base sleep event with appropriate end time
        let finalEndTime: Date
        if includeEndTime {
            finalEndTime = endTime
        } else if startImmediately {
            // If starting immediately with no end time, use current time + 30 min as placeholder
            finalEndTime = Date().addingTimeInterval(30 * 60)
        } else {
            // If not starting immediately and no end time, use start time + 30 min as placeholder
            finalEndTime = startTime.addingTimeInterval(30 * 60)
        }
        
        let sleepEvent = SleepEvent(
            date: startTime,
            sleepType: .nap, // Only allow naps
            endTime: finalEndTime,
            notes: notes,
            isTemplate: false,
            isOngoing: startImmediately, // Mark as ongoing if starting immediately
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
                endTime: endTime,
                notes: notes,
                isTemplate: true
            ))
            
            dataStore.baby = updatedBaby
        }
        
        presentationMode.wrappedValue.dismiss()
    }
}
