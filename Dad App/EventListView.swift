//
//  EventListView.swift
//  Dad App
//
//  Created by Ash Beech on 06/03/2025.
//

import SwiftUI

struct EventListView: View {
    @EnvironmentObject var dataStore: DataStore
    let events: [Event]
    let date: Date
    @Binding var selectedEvent: Event?
    
    // Add a UUID for forcing refreshes
    @State private var listRefreshID = UUID()
    @State private var refreshTimer: Timer?
    
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
                    EventRow(event: event, date: date)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            // Check if it's an ongoing nap first
                            if event.type == .sleep,
                               let sleepEvent = dataStore.getSleepEvent(id: event.id, for: date),
                               sleepEvent.isOngoing && sleepEvent.sleepType == .nap && Calendar.current.isDateInToday(date) {
                                // For ongoing naps, don't allow editing
                                // Instead, ensure it's the active nap in NowFocusView
                                let activeEvent = ActiveEvent.from(sleepEvent: sleepEvent)
                                NotificationCenter.default.post(
                                    name: NSNotification.Name("SetActiveNap"),
                                    object: activeEvent
                                )
                                
                                // Provide haptic feedback to indicate action was taken
                                let generator = UIImpactFeedbackGenerator(style: .light)
                                generator.impactOccurred()
                                
                                return
                            }
                            
                            // For other events, continue with normal editing logic
                            if dataStore.isEditingAllowed(for: date) {
                                selectedEvent = event
                            } else {
                                // Show visual feedback that editing is locked
                                let generator = UINotificationFeedbackGenerator()
                                generator.notificationOccurred(.warning)
                            }
                        }
                        // Add a slightly different styling for past dates that are locked
                        .opacity(isPastDateLocked() ? 0.8 : 1.0)
                }
            }
            .listStyle(PlainListStyle())
            .scrollContentBackground(.visible)
            .scrollDismissesKeyboard(.immediately)
            .id(listRefreshID)
            .onAppear {
                setupRefreshTimer()
            }
            .onDisappear {
                refreshTimer?.invalidate()
                refreshTimer = nil
                NotificationCenter.default.removeObserver(self)
            }
        }
    }
    
    private func isPastDateLocked() -> Bool {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let checkDate = calendar.startOfDay(for: date)
        return checkDate < today && !dataStore.isPastDateEditingEnabled
    }
    
    // Add method to force refresh the entire list (use sparingly)
    private func refreshList() {
        //print("Refreshing entire event list")
        listRefreshID = UUID()
    }
    
    // Set up a timer for periodic checks, but not frequent refreshes
    private func setupRefreshTimer() {
        // Only refresh every 10 seconds to check for ongoing events
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 10, repeats: true) { _ in
            if hasOngoingEvents() {
                // No need to refresh the whole list, individual rows handle their own timers
                // This is just to periodically check if we need to do cleanup
            }
        }
    }
    
    // Helper method to check if there are any ongoing events in the list
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
    let date: Date
    @State private var currentFormattedDuration: String = ""
    @State private var timerID: UUID = UUID()
    @State private var isPaused: Bool = false
    
    // Use the shared timer manager
    @StateObject private var timerManager = NapTimerManager.shared
    
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
                .opacity(isPastDateLocked() ? 0.8 : 1.0)
                .onTapGesture {
                    // Check if editing is allowed before allowing selection
                    if dataStore.isEditingAllowed(for: date) {
                        NotificationCenter.default.post(name: NSNotification.Name("EventSelected"), object: event)
                    } else {
                        showLockFeedback()
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
                                    //print("EventRow received pause change: isPaused=\(isPaused)")
                                    
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
                                    // Force a refresh
                                    timerID = UUID()
                                }
                            }
                        }
                        .onDisappear {
                            // Clean up observer when view disappears
                            NotificationCenter.default.removeObserver(self)
                        }
                        .id(timerID) // Force refresh when timer ID changes
                        .onReceive(timerManager.$timerTick) { _ in
                            // Update duration from shared timer
                            if let updatedSleepEvent = dataStore.getSleepEvent(id: event.id, for: date) {
                                updateCurrentDuration(sleepEvent: updatedSleepEvent)
                            }
                        }
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
    
    // Helper to check if we're dealing with a locked past date
    private func isPastDateLocked() -> Bool {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let checkDate = calendar.startOfDay(for: date)
        return checkDate < today && !dataStore.isPastDateEditingEnabled
    }
    
    private func showLockFeedback() {
        // Provide haptic feedback
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.warning)
    }
    
    private func updateCurrentDuration(sleepEvent: SleepEvent) {
        // Use shared timer manager to calculate and format duration
        let elapsedTime = timerManager.calculateEffectiveDuration(sleepEvent: sleepEvent)
        let newFormattedDuration = timerManager.formatDuration(elapsedTime)
        
        // Only update if the displayed time has changed
        if newFormattedDuration != currentFormattedDuration {
            currentFormattedDuration = newFormattedDuration
            timerID = UUID() // Force view update
        }
    }
    
    private func eventTitle() -> String {
            switch event.type {
            case .goal:
                if let date = Calendar.current.date(from: Calendar.current.dateComponents([.year, .month, .day], from: event.date)),
                   let goalEvent = dataStore.getGoalEvent(id: event.id, for: date) {
                    // Calculate days remaining until deadline
                    let calendar = Calendar.current
                    let now = Date()
                    let components = calendar.dateComponents([.day], from: now, to: goalEvent.date)
                    
                    if let daysRemaining = components.day {
                        if daysRemaining < 0 {
                            return "Goal: \(goalEvent.title) (Overdue)"
                        } else if daysRemaining == 0 {
                            return "Goal: \(goalEvent.title) (Due today)"
                        } else {
                            return "Goal: \(goalEvent.title) (\(daysRemaining) days)"
                        }
                    }
                    return "Goal: \(goalEvent.title)"
                }
                return "Goal"
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
                        // CRITICAL FIX: Add duration for completed naps
                        if !sleepEvent.isOngoing {
                            // Calculate duration for display
                            let duration: TimeInterval
                            if let actualDuration = sleepEvent.actualSleepDuration {
                                // Use actual recorded duration if available
                                duration = actualDuration
                            } else {
                                // Otherwise calculate from end time
                                duration = sleepEvent.endTime.timeIntervalSince(sleepEvent.date)
                            }
                            
                            // Format duration nicely with seconds for very short durations
                            let hours = Int(duration) / 3600
                            let minutes = (Int(duration) % 3600) / 60
                            let seconds = Int(duration) % 60
                            
                            if hours > 0 {
                                return "Nap: \(hours)h \(minutes)m"
                            } else if minutes > 0 {
                                return "Nap: \(minutes)m"
                            } else {
                                // CRITICAL FIX: Show seconds when duration is less than a minute
                                return "Nap: \(seconds)s"
                            }
                        }
                        return "Nap"
                    case .bedtime:
                        return "Bedtime"
                    case .waketime:
                        return "Wake Up"
                    }
                }
                return "Sleep"
            case .task:
                if let date = Calendar.current.date(from: Calendar.current.dateComponents([.year, .month, .day], from: event.date)),
                   let taskEvent = dataStore.getTaskEvent(id: event.id, for: date) {
                    
                    // Always use the past tense title for display, regardless of completion status
                    return taskEvent.pastTenseTitle
                }
                return "Task"
            }
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
            if let date = Calendar.current.date(from: Calendar.current.dateComponents([.year, .month, .day], from: event.date)),
               let taskEvent = dataStore.getTaskEvent(id: event.id, for: date) {
                
                // Different icons based on task style (reminder vs. duration) and completion status
                if taskEvent.hasEndTime {
                    return Image(systemName: taskEvent.completed ? "checkmark.circle.fill" : "circle.dashed")
                        .foregroundColor(.green)
                } else {
                    return Image(systemName: taskEvent.completed ? "bell.badge.fill" : "bell.fill")
                        .foregroundColor(.green)
                }
            }
            return Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.green)
        case .goal:
            return Image(systemName: "checkmark.circle.fill") // TODO: placeholder currently
                .foregroundColor(.green)
        }
    }
    
    private func formattedTime() -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: event.date)
    }
    
}
