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
    @State private var elapsedTime: TimeInterval = 0
    @State private var timer: Timer?
    @State private var currentFormattedDuration: String = ""
    
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
                        .foregroundColor(.purple)
                        .fontWeight(.medium)
                        .onAppear {
                            // Start a timer to update the duration display
                            setupTimerForLiveUpdates(sleepEvent: sleepEvent)
                        }
                        .onDisappear {
                            // Clean up timer when view disappears
                            timer?.invalidate()
                            timer = nil
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
    
    // Add this method to set up the timer for live updates
    private func setupTimerForLiveUpdates(sleepEvent: SleepEvent) {
        // Calculate initial duration
        updateCurrentDuration(sleepEvent: sleepEvent)
        
        // Set up timer for real-time updates (every 0.5 seconds)
        timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { _ in
            updateCurrentDuration(sleepEvent: sleepEvent)
        }
    }
    
    // Add this method to update the current duration
    private func updateCurrentDuration(sleepEvent: SleepEvent) {
        let duration = SleepUtilities.calculateEffectiveDuration(sleepEvent: sleepEvent)
        currentFormattedDuration = SleepUtilities.formatDuration(duration)
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
        case .task: return "Todo"
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
                    return Image(systemName: "moon.zzz.fill")
                        .foregroundColor(.purple)
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
            return Image(systemName: "task.fill")
                .foregroundColor(.purple)
        }
    }
}
