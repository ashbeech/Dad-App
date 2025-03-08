//
//  ContentView.swift
//  Dad App
//
//  Created by Ashley Davison on 06/03/2025.
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject var dataStore: DataStore
    @State private var currentDate = Date()
    @State private var selectedEvent: Event? = nil
    @State private var showingAddSheet = false
    @State private var showingSettingsSheet = false
    @State private var filteredEventTypes: [EventType]? = nil
    @State private var showingNapActionSheet = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Top section with date navigation only (baby name removed)
            VStack(spacing: 4) {
                // Date navigation
                DateNavigationView(currentDate: $currentDate)
                
                // Secondary navigation bar with undo and redo
                SecondaryNavBar(
                    onUndoTapped: {
                        dataStore.undoLastChange()
                    },
                    onRedoTapped: {
                        dataStore.redoLastChange()
                    },
                    canUndo: !dataStore.lastEventStates.isEmpty,
                    canRedo: !dataStore.redoEventStates.isEmpty
                )
            }
            .padding(.bottom, 4)
            
            // Donut chart
            let events = filteredEvents(from: dataStore.getEvents(for: currentDate))
            DonutChartView(date: currentDate, events: events, selectedEvent: $selectedEvent, filteredEventTypes: $filteredEventTypes)
                .frame(height: UIScreen.main.bounds.height * 0.38)
                .padding(.horizontal)
                .environmentObject(dataStore)
            
            // Category bar
            CategoryBarView(selectedCategories: $filteredEventTypes)
                .frame(height: UIScreen.main.bounds.height * 0.08)
                .padding(.horizontal)
                .padding(.vertical, 4)
            
            // Event list - expanded to take more space
            EventListView(events: events, selectedEvent: $selectedEvent)
                .frame(maxHeight: .infinity)
                .environmentObject(dataStore)
            
            // Add button - positioned closer to bottom
            Button(action: {
                showingAddSheet = true
            }) {
                ZStack {
                    Circle()
                        .fill(Color.blue)
                        .frame(width: 60, height: 60)
                    
                    Image(systemName: "plus")
                        .font(.title)
                        .foregroundColor(.white)
                }
            }
            .padding(.bottom, 8)
        }
        .sheet(isPresented: $showingAddSheet) {
            AddEventView(date: currentDate)
                .environmentObject(dataStore)
        }
        .sheet(item: $selectedEvent) { event in
            EditEventView(event: event, date: currentDate)
                .environmentObject(dataStore)
        }
        .sheet(isPresented: $showingSettingsSheet) {
            BabySettingsView()
                .environmentObject(dataStore)
        }
        .toolbar {
            // Leading item - Baby's name
            ToolbarItem(placement: .navigationBarLeading) {
                Text(dataStore.baby.name)
                    .font(.headline)
                    .foregroundColor(.primary)
            }
            
            // Trailing item - Settings button
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: {
                    showingSettingsSheet = true
                }) {
                    Image(systemName: "gear")
                }
            }
        }
        .onAppear {
            if dataStore.getEvents(for: currentDate).isEmpty {
                dataStore.generateDailySchedule(for: currentDate)
            }
        }
        .onChange(of: currentDate) { _, newDate in
            // Generate daily events when date changes, but only if no events exist
            if dataStore.getEvents(for: newDate).isEmpty {
                dataStore.generateDailySchedule(for: newDate)
            }
        }
    }
    
    internal func filteredEvents(from events: [Event]) -> [Event] {
        if let types = filteredEventTypes {
            // Filter regular events according to the selected types
            let filteredRegularEvents = events.filter { types.contains($0.type) }
            
            // Always include wake and bedtime events regardless of filter
            let wakeAndBedtimeEvents = events.filter { event in
                if event.type == .sleep,
                   let date = Calendar.current.date(from: Calendar.current.dateComponents([.year, .month, .day], from: event.date)),
                   let sleepEvent = dataStore.getSleepEvent(id: event.id, for: date) {
                    return sleepEvent.sleepType == .waketime || sleepEvent.sleepType == .bedtime
                }
                return false
            }
            
            // Combine and return all events
            return filteredRegularEvents + wakeAndBedtimeEvents
        }
        return events
    }
}

struct SecondaryNavBar: View {
    var onUndoTapped: () -> Void
    var onRedoTapped: () -> Void
    var canUndo: Bool
    var canRedo: Bool
    
    var body: some View {
        HStack {
            Button(action: onUndoTapped) {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.uturn.backward")
                    Text("Undo")
                }
                .font(.subheadline)
                .foregroundColor(canUndo ? .blue : .gray)
                .padding(.vertical, 6)
                .padding(.horizontal, 12)
                .background(canUndo ? Color.blue.opacity(0.1) : Color.gray.opacity(0.1))
                .cornerRadius(8)
            }
            .buttonStyle(PlainButtonStyle())
            .disabled(!canUndo)
            
            Spacer()
            
            Button(action: onRedoTapped) {
                HStack(spacing: 6) {
                    Text("Redo")
                    Image(systemName: "arrow.uturn.forward")
                }
                .font(.subheadline)
                .foregroundColor(canRedo ? .blue : .gray)
                .padding(.vertical, 6)
                .padding(.horizontal, 12)
                .background(canRedo ? Color.blue.opacity(0.1) : Color.gray.opacity(0.1))
                .cornerRadius(8)
            }
            .buttonStyle(PlainButtonStyle())
            .disabled(!canRedo)
        }
        .padding(.horizontal)
    }
}
