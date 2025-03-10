//
//  EventListView.swift
//  Dad App
//
//  Created by Ashley Davison on 06/03/2025.
//

import SwiftUI

struct EventListView: View {
    @EnvironmentObject var dataStore: DataStore
    let events: [Event]
    @Binding var selectedEvent: Event?
    
    // Add timer for refreshing the list
    @State private var refreshTimer: Timer?
    @State private var refreshTrigger: Bool = false
    
    var body: some View {
        if events.isEmpty {
            VStack {
                Spacer()
                Text("No events to display")
                    .font(.headline)
                    .foregroundColor(.gray)
                Spacer()
            }
        } else {
            List {
                ForEach(events.sorted(by: { $0.date < $1.date }), id: \.id) { event in
                    EventRow(event: event)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            selectedEvent = event
                        }
                }
            }
            .listStyle(PlainListStyle())
            // Hidden element that forces the list to update when refreshTrigger changes
            .background(
                Color.clear
                    .frame(width: 0, height: 0)
                    .onAppear {
                        setupRefreshTimer()
                    }
                    .onDisappear {
                        refreshTimer?.invalidate()
                        refreshTimer = nil
                    }
            )
        }
    }
    
    // Add method to set up a timer for periodic list refreshes
    private func setupRefreshTimer() {
        // Refresh the list every 0.5 seconds to update ongoing nap times
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { _ in
            if hasOngoingEvents() {
                refreshTrigger.toggle()
            }
        }
    }
    
    // Add method to check if there are any ongoing events in the list
    private func hasOngoingEvents() -> Bool {
        for event in events {
            if event.type == .sleep,
               let date = Calendar.current.date(from: Calendar.current.dateComponents([.year, .month, .day], from: event.date)),
               let sleepEvent = dataStore.getSleepEvent(id: event.id, for: date),
               sleepEvent.isOngoing && sleepEvent.sleepType == .nap {
                return true
            }
        }
        return false
    }
}

struct EventRow: View {
    @EnvironmentObject var dataStore: DataStore
    let event: Event
    
    // Add these state variables
    @State private var currentFormattedDuration: String = ""
    @State private var timerID: UUID = UUID()
    @State private var localTimer: Timer? = nil
    @State private var isPaused: Bool = false
    
    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                HStack {
                    Text(eventTitle())
                        .font(.headline)
                    
                    // Show live indicator for ongoing naps
                    if event.type == .sleep,
                       let date = Calendar.current.date(from: Calendar.current.dateComponents([.year, .month, .day], from: event.date)),
                       let sleepEvent = dataStore.getSleepEvent(id: event.id, for: date),
                       sleepEvent.isOngoing && sleepEvent.sleepType == .nap {
                        
                        if sleepEvent.isPaused {
                            Text("PAUSED")
                                .font(.caption)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.orange.opacity(0.2))
                                .foregroundColor(.orange)
                                .cornerRadius(4)
                        } else {
                            Circle()
                                .fill(Color.red)
                                .frame(width: 8, height: 8)
                                .padding(.leading, 2)
                            Text("LIVE")
                                .font(.caption)
                                .foregroundColor(.red)
                        }
                    }
                }
                
                Text(formattedTime())
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                // For ongoing naps, show elapsed time
                if event.type == .sleep,
                   let date = Calendar.current.date(from: Calendar.current.dateComponents([.year, .month, .day], from: event.date)),
                   let sleepEvent = dataStore.getSleepEvent(id: event.id, for: date),
                   sleepEvent.isOngoing && sleepEvent.sleepType == .nap {
                    
                    Text("Duration: \(currentFormattedDuration)")
                        .font(.caption)
                        .foregroundColor(sleepEvent.isPaused ? .orange : .purple)
                        .fontWeight(.medium)
                        .onAppear {
                            // Initialize state when view appears
                            isPaused = sleepEvent.isPaused
                            updateCurrentDuration(sleepEvent: sleepEvent)
                            
                            // Start a timer if not paused
                            if !isPaused {
                                startTimer(sleepEvent: sleepEvent)
                            }
                            
                            // Listen for pause state changes
                            NotificationCenter.default.addObserver(
                                forName: NSNotification.Name("NapPauseStateChanged"),
                                object: nil,
                                queue: .main
                            ) { notification in
                                if let eventId = notification.object as? UUID,
                                   eventId == event.id,
                                   let updatedSleepEvent = dataStore.getSleepEvent(id: event.id, for: date) {
                                    // Update our local state
                                    isPaused = updatedSleepEvent.isPaused
                                    print("EventRow received pause change: isPaused=\(isPaused)")
                                    
                                    // Manage timer based on new state
                                    if isPaused {
                                        stopTimer()
                                    } else {
                                        startTimer(sleepEvent: updatedSleepEvent)
                                    }
                                    
                                    // Update duration immediately
                                    updateCurrentDuration(sleepEvent: updatedSleepEvent)
                                }
                            }
                            
                            // Listen for nap stop events
                            NotificationCenter.default.addObserver(
                                forName: NSNotification.Name("NapStopped"),
                                object: nil,
                                queue: .main
                            ) { notification in
                                if let eventId = notification.object as? UUID,
                                   eventId == event.id {
                                    // Stop our timer
                                    stopTimer()
                                    
                                    // Force a refresh
                                    timerID = UUID()
                                }
                            }
                        }
                        .onDisappear {
                            // Clean up timer and observer when view disappears
                            stopTimer()
                            NotificationCenter.default.removeObserver(self)
                        }
                        .id(timerID) // Force refresh when timer ID changes
                }
                
                if !event.notes.isEmpty {
                    Text(event.notes)
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            }
            
            Spacer()
            
            eventIcon()
                .font(.title)
        }
        .padding(.vertical, 4)
    }
    
    private func startTimer(sleepEvent: SleepEvent) {
        // Stop any existing timer
        stopTimer()
        
        print("Starting event row timer")
        localTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            updateCurrentDuration(sleepEvent: sleepEvent)
        }
    }
    
    private func stopTimer() {
        if localTimer != nil {
            print("Stopping event row timer")
            localTimer?.invalidate()
            localTimer = nil
        }
    }
    
    private func updateCurrentDuration(sleepEvent: SleepEvent) {
        let elapsedTime = calculateEffectiveDuration(sleepEvent: sleepEvent)
        currentFormattedDuration = formatDuration(elapsedTime)
    }
    
    private func calculateEffectiveDuration(sleepEvent: SleepEvent) -> TimeInterval {
        let now = Date()
        var totalPauseTime: TimeInterval = 0
        
        // Calculate total pause time from completed intervals
        for interval in sleepEvent.pauseIntervals {
            totalPauseTime += interval.resumeTime.timeIntervalSince(interval.pauseTime)
        }
        
        // If currently paused, add the current pause interval
        if sleepEvent.isPaused, let pauseTime = sleepEvent.lastPauseTime {
            totalPauseTime += now.timeIntervalSince(pauseTime)
        }
        
        // Calculate total elapsed time
        return now.timeIntervalSince(sleepEvent.date) - totalPauseTime
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let hours = Int(duration) / 3600
        let minutes = (Int(duration) % 3600) / 60
        let seconds = Int(duration) % 60
        
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%02d:%02d", minutes, seconds)
        }
    }
    
    private func eventTitle() -> String {
        switch event.type {
        case .feed:
            if let date = Calendar.current.date(from: Calendar.current.dateComponents([.year, .month, .day], from: event.date)),
               let feedEvent = dataStore.getFeedEvent(id: event.id, for: date) {
                return "Feed: \(Int(feedEvent.amount))ml"
            }
            return "Feed"
        case .sleep:
            if let date = Calendar.current.date(from: Calendar.current.dateComponents([.year, .month, .day], from: event.date)),
               let sleepEvent = dataStore.getSleepEvent(id: event.id, for: date) {
                switch sleepEvent.sleepType {
                case .nap:
                    return "Nap"
                case .bedtime:
                    return "Bedtime"
                case .waketime:
                    return "Wake Up"
                }
            }
            return "Sleep"
        case .task: return "Task"
        }
    }
    
    private func formattedTime() -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: event.date)
    }
    
    private func eventIcon() -> some View {
        switch event.type {
        case .feed:
            return Image(systemName: "cup.and.saucer.fill")
                .foregroundColor(.blue)
        case .sleep:
            if let date = Calendar.current.date(from: Calendar.current.dateComponents([.year, .month, .day], from: event.date)),
               let sleepEvent = dataStore.getSleepEvent(id: event.id, for: date) {
                switch sleepEvent.sleepType {
                case .nap:
                    if sleepEvent.isOngoing && sleepEvent.isPaused {
                        return Image(systemName: "moon.fill")
                            .foregroundColor(.orange)
                    } else {
                        return Image(systemName: "moon.zzz.fill")
                            .foregroundColor(.purple)
                    }
                case .bedtime:
                    return Image(systemName: "bed.double.fill")
                        .foregroundColor(.indigo)
                case .waketime:
                    return Image(systemName: "sun.max.fill")
                        .foregroundColor(.orange)
                }
            }
            return Image(systemName: "moon.zzz.fill")
                .foregroundColor(.green)
        case .task:
            return Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.green)
        }
    }
}
