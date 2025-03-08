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
        }
    }
}

struct EventRow: View {
    @EnvironmentObject var dataStore: DataStore
    let event: Event
    
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
                                
                                let duration = SleepUtilities.calculateEffectiveDuration(sleepEvent: sleepEvent)
                                Text("Duration: \(SleepUtilities.formatDuration(duration))")
                                    .font(.caption)
                                    .foregroundColor(.purple)
                                    .fontWeight(.medium)
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
