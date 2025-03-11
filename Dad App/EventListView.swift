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
                    EventRow(event: event)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            selectedEvent = event
                        }
                    // Add a more stable ID that doesn't change with every timer update
                        .id("event-row-\(event.id)")
                }
            }
            .listStyle(PlainListStyle())
            .id(listRefreshID) // Only refresh the entire list when needed
            .onAppear {
                setupRefreshTimer()
                
                // Listen for pause state changes that might need to refresh the entire list
                NotificationCenter.default.addObserver(
                    forName: NSNotification.Name("NapPauseStateChanged"),
                    object: nil,
                    queue: .main
                ) { _ in
                    // Avoid immediate refresh which can cause flickering
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        refreshList()
                    }
                }
                
                // Listen for nap stopped events
                NotificationCenter.default.addObserver(
                    forName: NSNotification.Name("NapStopped"),
                    object: nil,
                    queue: .main
                ) { _ in
                    // Refresh after a slight delay
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        refreshList()
                    }
                }
            }
            .onDisappear {
                refreshTimer?.invalidate()
                refreshTimer = nil
                NotificationCenter.default.removeObserver(self)
            }
        }
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
    
    // Add these state variables
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
