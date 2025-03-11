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
    @State private var initialEventTime: Date = Date()
    
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
            DonutChartView(
                date: currentDate,
                events: events,
                selectedEvent: $selectedEvent,
                filteredEventTypes: $filteredEventTypes,
                onAddEventTapped: { tappedTime in
                    // Save the tapped time for use in AddEventView
                    initialEventTime = tappedTime
                    
                    // Log for debugging
                    //print("ContentView received tapped time: \(formatTime(tappedTime))")
                    
                    // Show the add sheet
                    showingAddSheet = true
                }
            )
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
            AddEventView(date: currentDate, initialTime: initialEventTime)
                .environmentObject(dataStore)
            //.slideAnimation(isPresented: $showingAddSheet)
            //.onAppear {
            // Force log to verify the initialTime value
            //print("ADD EVENT VIEW APPEARED with initialTime: \(formatTime(initialEventTime))")
            //}
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
        // If no filter, return all events
        if filteredEventTypes == nil {
            return events
        }
        
        guard let types = filteredEventTypes else {
            return events
        }
        
        // Create a helper function to check if an event should be shown
        func shouldIncludeEvent(_ event: Event) -> Bool {
            // First check if the event type matches the filter
            if types.contains(event.type) {
                // For sleep events, apply additional filtering
                if event.type == .sleep,
                   let date = Calendar.current.date(from: Calendar.current.dateComponents([.year, .month, .day], from: event.date)),
                   let sleepEvent = dataStore.getSleepEvent(id: event.id, for: date) {
                    
                    // Special case: Wake and bedtime events only shown when filter is "All" or specifically "Sleep"
                    if sleepEvent.sleepType == .waketime || sleepEvent.sleepType == .bedtime {
                        // Only include wake/bedtime when Sleep filter is active or All (no filter)
                        return true
                    }
                    
                    // When sleep filter is active, include naps
                    return sleepEvent.sleepType == .nap
                }
                return true
            }
            
            // Special case: Only include wake and bedtime events when "All" or "Sleep" filters are active
            if event.type == .sleep,
               let date = Calendar.current.date(from: Calendar.current.dateComponents([.year, .month, .day], from: event.date)),
               let sleepEvent = dataStore.getSleepEvent(id: event.id, for: date),
               (sleepEvent.sleepType == .waketime || sleepEvent.sleepType == .bedtime) {
                
                // Only include wake/bedtime events when "All" or "Sleep" filters are active
                return types.isEmpty || types.contains(.sleep)
            }
            
            return false
        }
        
        // Apply our filtering function to the events
        let filteredEvents = events.filter(shouldIncludeEvent)
        
        // Return filtered events with duplicates removed
        var uniqueEvents: [Event] = []
        var seenIDs: Set<UUID> = []
        
        for event in filteredEvents {
            if !seenIDs.contains(event.id) {
                uniqueEvents.append(event)
                seenIDs.insert(event.id)
            }
        }
        
        return uniqueEvents
    }
}

/*
 struct SlideAnimationModifier: ViewModifier {
 @Binding var isPresented: Bool
 let offsetY: CGFloat
 
 func body(content: Content) -> some View {
 content
 .offset(y: isPresented ? 0 : offsetY)
 .animation(.easeInOut(duration: 0.3), value: isPresented)
 }
 }*/
/*
 extension View {
 func slideAnimation(isPresented: Binding<Bool>, offsetY: CGFloat = UIScreen.main.bounds.height) -> some View {
 self.modifier(SlideAnimationModifier(isPresented: isPresented, offsetY: offsetY))
 }
 
 }
 */

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
