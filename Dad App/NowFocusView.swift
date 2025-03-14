//
//  NowFocusView.swift
//  Dad App
//
//  Created by Ashley Davison on 08/03/2025.
//

import SwiftUI
import Combine

struct NowFocusView: View {
    @EnvironmentObject var dataStore: DataStore
    @Binding var currentActiveEvent: ActiveEvent?
    let date: Date
    
    // State management
    @State private var localIsPaused: Bool = false
    @State private var displayTime: String = "00:00"
    @State private var timerID: UUID = UUID()
    @State private var viewRefreshTrigger = UUID()
    
    // Use shared timer manager instead of local timer
    @StateObject private var timerManager = NapTimerManager.shared
    
    var body: some View {
        ZStack {
            if let activeEvent = currentActiveEvent, activeEvent.type == .sleep,
               let sleepEvent = dataStore.getSleepEvent(id: activeEvent.id, for: date),
               sleepEvent.sleepType == .nap {
                
                VStack {
                    Text("Nap")
                        .font(.headline)
                        .padding(.bottom, 5)
                    
                    Text(displayTime)
                        .font(.system(size: 24, weight: .bold, design: .monospaced))
                        .foregroundColor(sleepEvent.isPaused ? .yellow : .white)
                        .padding(.bottom, 10)
                        .id(timerID) // Force refresh of just the time display
                    
                    HStack(spacing: 20) {
                        Button(action: {
                            togglePause(activeEvent: activeEvent, sleepEvent: sleepEvent)
                        }) {
                            ZStack {
                                Circle()
                                    .fill(Color.blue.opacity(0.2))
                                    .frame(width: 60, height: 60)
                                
                                Image(systemName: sleepEvent.isPaused ? "play.fill" : "pause.fill")
                                    .font(.title2)
                                    .foregroundColor(.blue)
                            }
                        }
                        
                        Button(action: {
                            stopNap(activeEvent: activeEvent, sleepEvent: sleepEvent)
                        }) {
                            ZStack {
                                Circle()
                                    .fill(Color.red.opacity(0.2))
                                    .frame(width: 60, height: 60)
                                
                                Image(systemName: "stop.fill")
                                    .font(.title2)
                                    .foregroundColor(.red)
                            }
                        }
                    }
                }
                .padding()
                .onAppear {
                    print("NowFocusView appeared with activeEvent")
                    // Initialize state
                    localIsPaused = sleepEvent.isPaused
                    updateDisplayTime(sleepEvent: sleepEvent)
                    
                    // Listen for pause state changes
                    NotificationCenter.default.addObserver(
                        forName: NSNotification.Name("NapPauseStateChanged"),
                        object: nil,
                        queue: .main
                    ) { notification in
                        if let eventId = notification.object as? UUID,
                           eventId == activeEvent.id,
                           let updatedSleepEvent = dataStore.getSleepEvent(id: activeEvent.id, for: date) {
                            // Update our local state
                            localIsPaused = updatedSleepEvent.isPaused
                            print("NowFocusView received pause change: isPaused=\(localIsPaused)")
                            
                            // Update duration immediately and force refresh
                            updateDisplayTime(sleepEvent: updatedSleepEvent)
                            timerID = UUID()
                        }
                    }
                    
                    // Listen for new active nap notifications
                    NotificationCenter.default.addObserver(
                        forName: NSNotification.Name("SetActiveNap"),
                        object: nil,
                        queue: .main
                    ) { notification in
                        if let newActiveEvent = notification.object as? ActiveEvent {
                            // Set this as the current active event
                            currentActiveEvent = newActiveEvent
                            
                            // Force immediate refresh
                            viewRefreshTrigger = UUID()
                            timerID = UUID()
                        }
                    }
                }
                .onDisappear {
                    NotificationCenter.default.removeObserver(self)
                }
                .onReceive(timerManager.$timerTick) { _ in
                    // Update the display time when the shared timer ticks
                    if let updatedSleepEvent = dataStore.getSleepEvent(id: activeEvent.id, for: date) {
                        updateDisplayTime(sleepEvent: updatedSleepEvent)
                    }
                }
                // CRITICAL FIX: Add ID using the viewRefreshTrigger to ensure view updates
                .id("nap-controls-\(viewRefreshTrigger)")
                
            } else if Calendar.current.isDateInToday(date) && !isAfterBedtime() {
                // Show the next upcoming event when no active event and it's today
                NextEventInfoView(date: date)
                    .environmentObject(dataStore)
                    // CRITICAL FIX: Add ID using the viewRefreshTrigger to ensure view updates
                    .id("next-event-\(viewRefreshTrigger)")
            } else if isPastDate(date) {
                // For past dates, show a message
                PastDateView(date: date)
            } else if Calendar.current.isDateInToday(date) && isAfterBedtime() {
                DayCompletionView()
                    // CRITICAL FIX: Add ID using the viewRefreshTrigger to ensure view updates
                    .id("day-completion-\(viewRefreshTrigger)")
            } else {
                // Show daily summary for future dates only
                FutureDateSummaryView(date: date)
                    .environmentObject(dataStore)
            }
            
        }
        .onChange(of: currentActiveEvent) { _, newActiveEvent in
            // When active event changes, update our local state
            if let newEvent = newActiveEvent,
               let sleepEvent = dataStore.getSleepEvent(id: newEvent.id, for: date) {
                localIsPaused = sleepEvent.isPaused
                updateDisplayTime(sleepEvent: sleepEvent)
                
                // Force view refresh when active event changes
                timerID = UUID()
                
                // CRITICAL FIX: Force complete view refresh
                viewRefreshTrigger = UUID()
            }
        }
        // CRITICAL FIX: Add an onAppear handler to refresh the view when it appears
        .onAppear {
            // Determine if it's today and update view
            if Calendar.current.isDateInToday(date) {
                // Force a refresh
                viewRefreshTrigger = UUID()
                
                // Register for application state notifications
                NotificationCenter.default.addObserver(
                    forName: UIApplication.didBecomeActiveNotification,
                    object: nil,
                    queue: .main
                ) { _ in
                    print("NowFocusView detected app became active")
                    // Force view refresh when app becomes active
                    self.viewRefreshTrigger = UUID()
                }
            }
        }
        // CRITICAL FIX: Register for time updates specifically
        .onReceive(NotificationCenter.default.publisher(for: .NSCalendarDayChanged)) { _ in
            if Calendar.current.isDateInToday(date) {
                print("NowFocusView detected day change")
                // Force refresh on day change
                viewRefreshTrigger = UUID()
            }
        }
        // CRITICAL FIX: Connect to the shared timer to force periodic refreshes
        .onReceive(timerManager.$timerTick) { _ in
            // On every 10th tick, force a complete refresh if needed
            if timerManager.timerTick % 10 == 0 && Calendar.current.isDateInToday(date) {
                viewRefreshTrigger = UUID()
            }
        }
    }
    
    private func isPastDate(_ date: Date) -> Bool {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let checkDate = calendar.startOfDay(for: date)
        return checkDate < today
    }
    
    private func updateDisplayTime(sleepEvent: SleepEvent) {
        // Use the shared manager to calculate elapsed time
        let elapsedTime = timerManager.calculateEffectiveDuration(sleepEvent: sleepEvent)
        
        // Update the actual sleep duration in the data store periodically
        if !sleepEvent.isPaused && sleepEvent.isOngoing {
            var modifiedSleepEvent = sleepEvent
            modifiedSleepEvent.actualSleepDuration = elapsedTime
            // TODO: Maybe not most efficient thinng to be doing; saving every second to datastore.
            dataStore.updateSleepEvent(modifiedSleepEvent, for: date)
        }
        
        // Use the shared manager to format the time consistently
        let newDisplayTime = timerManager.formatDuration(elapsedTime)
        
        if newDisplayTime != displayTime {
            displayTime = newDisplayTime
            // Force refresh of the display when time changes
            timerID = UUID()
        }
    }
    
    private func togglePause(activeEvent: ActiveEvent, sleepEvent: SleepEvent) {
        // Get the latest version of the sleep event
        guard let updatedSleepEvent = dataStore.getSleepEvent(id: sleepEvent.id, for: date) else {
            return
        }
        
        // Toggle the pause state
        let newPauseState = !updatedSleepEvent.isPaused
        print("Toggling pause state to: \(newPauseState)")
        
        // Now update the model with the new state
        let now = Date()
        var modifiedActiveEvent = activeEvent
        var modifiedSleepEvent = updatedSleepEvent
        
        // Calculate the current elapsed time before changing pause state
        let currentElapsedTime = timerManager.calculateEffectiveDuration(sleepEvent: updatedSleepEvent)
        
        if newPauseState {
            // Pausing
            modifiedActiveEvent.isPaused = true
            modifiedActiveEvent.lastPauseTime = now
            
            modifiedSleepEvent.isPaused = true
            modifiedSleepEvent.lastPauseTime = now
            
            // When pausing, save the current elapsed time as the actual sleep duration
            modifiedSleepEvent.actualSleepDuration = currentElapsedTime
            
            // Haptic feedback for pause
            let generator = UIImpactFeedbackGenerator(style: .medium)
            generator.impactOccurred()
        } else {
            // Resuming
            if let pauseTime = updatedSleepEvent.lastPauseTime {
                let newInterval = PauseInterval(pauseTime: pauseTime, resumeTime: now)
                
                modifiedActiveEvent.pauseIntervals.append(newInterval)
                modifiedSleepEvent.pauseIntervals.append(newInterval)
            }
            
            modifiedActiveEvent.isPaused = false
            modifiedActiveEvent.lastPauseTime = nil
            
            modifiedSleepEvent.isPaused = false
            modifiedSleepEvent.lastPauseTime = nil
            
            // Haptic feedback for resume
            let generator = UIImpactFeedbackGenerator(style: .light)
            generator.impactOccurred()
        }
        
        // Update the data store first
        dataStore.updateSleepEvent(modifiedSleepEvent, for: date)
        
        // Then update the active event binding
        currentActiveEvent = modifiedActiveEvent
        
        // Force a complete view refresh by generating a new timer ID
        timerID = UUID()
        
        // Force an immediate update of the display time
        updateDisplayTime(sleepEvent: modifiedSleepEvent)
        
        // Notify other components of the change
        NotificationCenter.default.post(
            name: NSNotification.Name("NapPauseStateChanged"),
            object: modifiedSleepEvent.id
        )
    }
    
    private func stopNap(activeEvent: ActiveEvent, sleepEvent: SleepEvent) {
        // Get the latest version of the sleep event
        guard let updatedSleepEvent = dataStore.getSleepEvent(id: sleepEvent.id, for: date) else {
            return
        }
        
        var modifiedSleepEvent = updatedSleepEvent
        
        // Set the end time to now
        let now = Date()
        modifiedSleepEvent.endTime = now
        
        // CRITICAL FIX: Save the EXACT duration that's currently displayed in the timer
        // This is the value shown to the user and must be preserved exactly
        
        // Calculate the current effective duration using the shared timer manager
        let displayedDuration = timerManager.calculateEffectiveDuration(sleepEvent: updatedSleepEvent)
        
        // Force log the exact duration we're saving
        //print("SAVING EXACT TIMER DURATION: \(formatDuration(displayedDuration))")
        
        // Explicitly set this duration as the actual sleep duration
        modifiedSleepEvent.actualSleepDuration = displayedDuration
        
        // Save pause intervals for record-keeping
        modifiedSleepEvent.pauseIntervals = activeEvent.pauseIntervals
        
        // Mark as no longer ongoing
        modifiedSleepEvent.isOngoing = false
        modifiedSleepEvent.isPaused = false
        modifiedSleepEvent.lastPauseTime = nil
        
        // Update the data store - do this AFTER setting all properties
        dataStore.updateSleepEvent(modifiedSleepEvent, for: date)
        
        // Verify the data was saved correctly by retrieving it again
        if let verifiedEvent = dataStore.getSleepEvent(id: sleepEvent.id, for: date) {
            //print("VERIFICATION - Saved duration: \(formatDuration(verifiedEvent.actualSleepDuration ?? 0))")
        }
        
        // Post notification to update UI
        NotificationCenter.default.post(name: NSNotification.Name("NapStopped"), object: modifiedSleepEvent.id)
        
        // Clear the active event
        currentActiveEvent = nil
    }
    
    // Helper function to format duration for logging
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
    
    private func isAfterBedtime() -> Bool {
        let now = Date()
        
        // Find the actual bedtime event if it exists, otherwise use the default from baby settings
        let bedtimeEvent = dataStore.findBedtimeEvent(for: date)
        let bedTime = bedtimeEvent?.date ?? dataStore.baby.bedTime
        
        // Get current time components
        let calendar = Calendar.current
        let nowComponents = calendar.dateComponents([.hour, .minute], from: now)
        
        // Get bedtime components
        let bedComponents = calendar.dateComponents([.hour, .minute], from: bedTime)
        
        // Convert both to minutes since midnight for comparison
        let nowMinutes = (nowComponents.hour ?? 0) * 60 + (nowComponents.minute ?? 0)
        let bedMinutes = (bedComponents.hour ?? 0) * 60 + (bedComponents.minute ?? 0)
        
        // CRITICAL FIX: For bedtimes after midnight, we need special handling
        if bedMinutes < 360 { // Assuming bedtime won't be before 6am
            // If now is after midnight but before bedtime, it's not after bedtime
            if nowMinutes < 360 && nowMinutes < bedMinutes {
                return false
            }
            
            // If now is after 6pm, it's after bedtime
            return nowMinutes >= 1080 // 6pm = 18 * 60 = 1080
        }
        
        return nowMinutes >= bedMinutes
    }
}

struct PastDateView: View {
    @EnvironmentObject var dataStore: DataStore
    let date: Date
    
    var body: some View {
        GeometryReader { geometry in
            let diameter = min(geometry.size.width + 25, geometry.size.height + 25)
            
            ZStack {
                Circle()
                    .fill(Color(UIColor.systemBackground).opacity(0.9))
                    .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
                
                VStack(spacing: 10) {
                    Image(systemName: "calendar.badge.clock")
                        .font(.system(size: diameter * 0.15))
                        .foregroundColor(.gray)
                    
                    Text("Past Date")
                        .font(.headline)
                        .foregroundColor(.gray)
                    
                    Text(formattedDate())
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    // Show different text based on lock state
                    Text(dataStore.isPastDateEditingEnabled ? "Editing enabled" : "View historical data only")
                        .font(.caption)
                        .foregroundColor(dataStore.isPastDateEditingEnabled ? .blue : .secondary)
                        .padding(.top, 5)
                    
                    // Add padlock button
                    Button(action: {
                        // Toggle the editing state with animation and haptic feedback
                        withAnimation(.spring()) {
                            dataStore.isPastDateEditingEnabled.toggle()
                        }
                        
                        // Provide haptic feedback when toggling
                        let generator = UIImpactFeedbackGenerator(style: .medium)
                        generator.impactOccurred()
                        
                        // Post notification so other views can update
                        NotificationCenter.default.post(
                            name: NSNotification.Name("PastDateEditingStateChanged"),
                            object: dataStore.isPastDateEditingEnabled
                        )
                    }) {
                        HStack {
                            Image(systemName: dataStore.isPastDateEditingEnabled ? "lock.open.fill" : "lock.fill")
                                .font(.system(size: 16))
                            Text(dataStore.isPastDateEditingEnabled ? "Lock Editing" : "Unlock Editing")
                                .font(.callout)
                        }
                        .padding(.vertical, 8)
                        .padding(.horizontal, 12)
                        .background(dataStore.isPastDateEditingEnabled ? Color.blue : Color.gray)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                    }
                    .padding(.top, 0)
                }
                .padding()
                .frame(width: diameter + 25, height: diameter + 25)
                .clipShape(Circle()) // Ensure content stays in circle
            }
            //.frame(width: diameter + 25, height: diameter + 25)
            .position(x: geometry.size.width/2, y: geometry.size.height/2)
        }
    }
    
    private func formattedDate() -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }
    
}

struct NextEventInfoView: View {
    @EnvironmentObject var dataStore: DataStore
    let date: Date
    
    @State private var nextEvent: (event: Event, timeRemaining: TimeInterval)? = nil
    @State private var timer: Timer?
    
    // Add state variables to track relevant data store changes
    @State private var eventsObserver: AnyCancellable?
    @State private var feedEventsObserver: AnyCancellable?
    @State private var sleepEventsObserver: AnyCancellable?
    
    var body: some View {
        VStack {
            if let next = nextEvent {
                VStack(spacing: 8) {
                    Text("Coming Up")
                        .font(.headline)
                        .foregroundColor(.gray)
                    
                    HStack(spacing: 12) {
                        Image(systemName: iconForEvent(next.event))
                            .font(.title)
                            .foregroundColor(.white)
                            .frame(width: 40, height: 40)
                            .background(colorForEvent(next.event))
                            .clipShape(Circle())
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text(titleForEvent(next.event))
                                .font(.headline)
                                .foregroundColor(.primary)
                            
                            Text("in \(formatTimeRemaining(next.timeRemaining))")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(Color(UIColor.secondarySystemBackground))
                    .cornerRadius(12)
                    .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
                }
                .padding(12)
                .background(Color(UIColor.systemBackground).opacity(0.9))
                .cornerRadius(16)
                .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
            } else {
                VStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.largeTitle)
                        .foregroundColor(.green)
                    
                    Text("All set for today")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Text("No more scheduled events")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                }
                .padding()
                .background(Color(UIColor.systemBackground).opacity(0.9))
                .cornerRadius(16)
                .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            // Set up observers for data store changes
            setupDataObservers()
            
            // Listen for direct notifications about event changes
            NotificationCenter.default.addObserver(
                forName: NSNotification.Name("EventDataChanged"),
                object: nil,
                queue: .main
            ) { _ in
                //print("Received EventDataChanged notification - refreshing next event view")
                findNextEvent()
            }
            
            // Find the next event immediately on appear
            findNextEvent()
            
            // Set up timer to refresh every 30 seconds to keep time remaining accurate
            timer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { _ in
                findNextEvent()
            }
        }
        .onDisappear {
            // Clean up all observers and timers when view disappears
            timer?.invalidate()
            timer = nil
            eventsObserver?.cancel()
            feedEventsObserver?.cancel()
            sleepEventsObserver?.cancel()
            
            // Remove NotificationCenter observer
            NotificationCenter.default.removeObserver(self)
        }
    }
    
    private func setupDataObservers() {
        // Observe changes to the general events dictionary
        eventsObserver = dataStore.$events.sink { _ in
            // When events change (added, deleted, etc.), update our display
            findNextEvent()
        }
        
        // Observe changes to feed events specifically
        feedEventsObserver = dataStore.$feedEvents.sink { _ in
            // When feed events change, update our display
            findNextEvent()
        }
        
        // Observe changes to sleep events specifically
        sleepEventsObserver = dataStore.$sleepEvents.sink { _ in
            // When sleep events change, update our display
            findNextEvent()
        }
    }
    
    private func findNextEvent() {
        let now = Date()
        let dateString = dataStore.formatDate(date)
        
        // Get all events for today
        let todayEvents = dataStore.events[dateString] ?? []
        
        // Create a variable to check if the event we're currently displaying still exists
        var currentEventExists = false
        
        // Filter for future events that haven't happened yet
        var futureEvents: [(event: Event, timeRemaining: TimeInterval)] = []
        
        for event in todayEvents {
            // Check if our currently displayed event still exists in the data
            if let current = nextEvent, current.event.id == event.id {
                currentEventExists = true
            }
            
            // Skip wake and bedtime events
            if event.type == .sleep,
               let sleepEvent = dataStore.getSleepEvent(id: event.id, for: date),
               (sleepEvent.sleepType == .waketime || sleepEvent.sleepType == .bedtime) {
                continue
            }
            
            // Skip ongoing events
            if event.type == .sleep,
               let sleepEvent = dataStore.getSleepEvent(id: event.id, for: date),
               sleepEvent.isOngoing {
                continue
            }
            
            // Calculate time remaining until this event
            let timeRemaining = event.date.timeIntervalSince(now)
            
            // Only include future events (positive time remaining)
            if timeRemaining > 0 {
                futureEvents.append((event, timeRemaining))
            }
        }
        
        // If our currently displayed event was deleted, force an update
        if nextEvent != nil && !currentEventExists {
            // Clear the currently displayed event if it no longer exists
            nextEvent = nil
        }
        
        // Sort by time remaining (closest first)
        futureEvents.sort { $0.timeRemaining < $1.timeRemaining }
        
        // Take the closest event
        let newNextEvent = futureEvents.first
        
        // Only update if the event has changed or time remaining has significantly changed
        if let new = newNextEvent, let current = nextEvent {
            // Check if it's a new event ID or the time difference is substantial (more than 30 seconds)
            let timeDifference = abs(new.timeRemaining - current.timeRemaining)
            if new.event.id != current.event.id || timeDifference > 30 {
                nextEvent = new
                //print("Updated next event: \(titleForEvent(new.event)) in \(formatTimeRemaining(new.timeRemaining))")
            }
        } else {
            // Either we had no event before or we have none now
            nextEvent = newNextEvent
            
            /*
            if let next = nextEvent {
                //print("Found new next event: \(titleForEvent(next.event)) in \(formatTimeRemaining(next.timeRemaining))")
            } else {
                //print("No upcoming events found")
            }
             */
        }
    }
    
    private func formatTimeRemaining(_ timeRemaining: TimeInterval) -> String {
        let minutes = Int(timeRemaining) / 60
        
        if minutes < 1 {
            return "less than a min"
        } else if minutes == 1 {
            return "1 min"
        } else if minutes < 60 {
            return "\(minutes) mins"
        } else {
            let hours = minutes / 60
            let remainingMinutes = minutes % 60
            
            if remainingMinutes == 0 {
                return "\(hours) \(hours == 1 ? "hour" : "hours")"
            } else {
                return "\(hours) \(hours == 1 ? "hour" : "hours"), \(remainingMinutes) \(remainingMinutes == 1 ? "min" : "mins")"
            }
        }
    }
    
    private func titleForEvent(_ event: Event) -> String {
        switch event.type {
        case .feed:
            if let feedEvent = dataStore.getFeedEvent(id: event.id, for: date) {
                return "Feed: \(Int(feedEvent.amount))ml"
            }
            return "Next Feed"
        case .sleep:
            if let sleepEvent = dataStore.getSleepEvent(id: event.id, for: date) {
                switch sleepEvent.sleepType {
                case .nap:
                    return "Nap Time"
                case .bedtime:
                    return "Bedtime"
                case .waketime:
                    return "Wake Up"
                }
            }
            return "Next Sleep"
        case .task:
            return "Next Task"
        }
    }
    
    private func iconForEvent(_ event: Event) -> String {
        switch event.type {
        case .feed:
            return "cup.and.saucer.fill"
        case .sleep:
            if let sleepEvent = dataStore.getSleepEvent(id: event.id, for: date) {
                switch sleepEvent.sleepType {
                case .nap:
                    return "moon.zzz.fill"
                case .bedtime:
                    return "bed.double.fill"
                case .waketime:
                    return "sun.max.fill"
                }
            }
            return "moon.zzz.fill"
        case .task:
            return "checkmark.circle.fill"
        }
    }
    
    private func colorForEvent(_ event: Event) -> Color {
        switch event.type {
        case .feed:
            return .blue
        case .sleep:
            if let sleepEvent = dataStore.getSleepEvent(id: event.id, for: date) {
                switch sleepEvent.sleepType {
                case .nap:
                    return .purple
                case .bedtime:
                    return .indigo
                case .waketime:
                    return .orange
                }
            }
            return .purple
        case .task:
            return .green
        }
    }
}

struct DayCompletionView: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "star.fill")
                .font(.system(size: 40))
                .foregroundColor(.yellow)
            
            Text("Well done on today!")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.primary)
            
            Text("Time to rest")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .padding()
        .transition(.opacity)
    }
}

struct FutureDateSummaryView: View {
    @EnvironmentObject var dataStore: DataStore
    let date: Date
    @State private var currentPage: Int = 0
    
    var body: some View {
        GeometryReader { geometry in
            let diameter = min(geometry.size.width, geometry.size.height)
            
            ZStack {
                // Circular background
                Circle()
                    .fill(Color(UIColor.systemBackground).opacity(0.9))
                    .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 4)
                
                // Content with clipping to ensure it stays in circle
                VStack(spacing: 3) {
                    /*
                     Text("Plan")
                     .font(.title3)
                     .foregroundColor(.gray)
                     .lineLimit(1)
                     .minimumScaleFactor(0.7)
                     */
                    // Horizontal pager (custom implementation)
                    ZStack {
                        // Only show the current page
                        if currentPage == 0 {
                            // Feed summary
                            VStack {
                                Image(systemName: "cup.and.saucer.fill")
                                    .font(.system(size: diameter * 0.15))
                                    .foregroundColor(.blue)
                                
                                Text("\(totalMilkVolume()) ml")
                                    .font(.title3)
                                    .fontWeight(.semibold)
                                
                                Text("\(feedCount()) feeds")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                            .padding(.vertical, 10)
                            .frame(width: diameter * 0.7)
                            .transition(.opacity)
                        } else if currentPage == 1 {
                            // Sleep summary
                            VStack {
                                Image(systemName: "moon.zzz.fill")
                                    .font(.system(size: diameter * 0.15))
                                    .foregroundColor(.purple)
                                
                                Text("\(totalNapHours())")
                                    .font(.title3)
                                    .fontWeight(.semibold)
                                
                                Text("\(napCount()) naps")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                            .padding(.vertical, 10)
                            .frame(width: diameter * 0.7)
                            .transition(.opacity)
                        } else if currentPage == 2 {
                            // Tasks summary
                            VStack {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: diameter * 0.15))
                                    .foregroundColor(.green)
                                
                                Text("\(taskCount())")
                                    .font(.title3)
                                    .fontWeight(.semibold)
                                
                                Text("tasks")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                            .padding(.vertical, 10)
                            .frame(width: diameter * 0.7)
                            .transition(.opacity)
                        }
                    }
                    .animation(.easeInOut, value: currentPage)
                    
                    // Page indicators
                    HStack(spacing: 12) {
                        ForEach(0..<3) { i in
                            Circle()
                                .fill(currentPage == i ? Color.blue : Color.gray.opacity(0.3))
                                .frame(width: 10, height: 10)
                        }
                    }
                    .padding(.bottom, 3)
                    
                    /*
                     // Daily tip
                     Text(getDailyTip())
                     .font(.footnote)
                     .foregroundColor(.primary)
                     .multilineTextAlignment(.center)
                     .lineLimit(2)
                     .minimumScaleFactor(0.7)
                     .padding(10)
                     .background(Color.blue.opacity(0.1))
                     .cornerRadius(8)
                     .padding(.horizontal, diameter * 0.05)
                     */
                }
                .padding(diameter * 0.05)
                .frame(width: diameter + 25, height: diameter + 25)
                .clipShape(Circle()) // Essential: clip content to circular shape
            }
            .frame(width: diameter + 25, height: diameter + 25)
            .position(x: geometry.size.width/2, y: geometry.size.height/2)
            .gesture(
                DragGesture()
                    .onEnded { value in
                        // Detect horizontal swipe
                        if value.translation.width < -20 {
                            // Swipe left - next page
                            withAnimation {
                                currentPage = min(currentPage + 1, 2)
                            }
                        } else if value.translation.width > 20 {
                            // Swipe right - previous page
                            withAnimation {
                                currentPage = max(currentPage - 1, 0)
                            }
                        }
                    }
            )
            // Auto-rotate through pages every 3 seconds
            .onAppear {
                startPageRotationTimer()
            }
        }
    }
    
    // Timer to auto-rotate through pages
    private func startPageRotationTimer() {
        Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { timer in
            withAnimation {
                // Cycle through pages
                currentPage = (currentPage + 1) % 3
            }
        }
    }
    
    // All the existing helper methods remain the same
    
    private func formattedDate() -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }
    
    private func totalMilkVolume() -> Int {
        let events = dataStore.getEvents(for: date)
        var total: Double = 0
        
        for event in events where event.type == .feed {
            if let feedEvent = dataStore.getFeedEvent(id: event.id, for: date) {
                total += feedEvent.amount
            }
        }
        
        // If we have no data for this day yet, predict from last 3 days
        if total == 0 {
            total = predictTotalMilkVolume()
        }
        
        return Int(total)
    }
    
    private func feedCount() -> Int {
        let events = dataStore.getEvents(for: date)
        let feedEvents = events.filter { $0.type == .feed }
        
        // If we have no data for this day yet, predict from previous patterns
        if feedEvents.isEmpty {
            return predictFeedCount()
        }
        
        return feedEvents.count
    }
    
    private func napCount() -> Int {
        let events = dataStore.getEvents(for: date)
        let napEvents = events.filter {
            if $0.type == .sleep,
               let sleepEvent = dataStore.getSleepEvent(id: $0.id, for: date),
               sleepEvent.sleepType == .nap {
                return true
            }
            return false
        }
        
        // If we have no data for this day yet, predict from previous patterns
        if napEvents.isEmpty {
            return predictNapCount()
        }
        
        return napEvents.count
    }
    
    private func totalNapHours() -> String {
        let events = dataStore.getEvents(for: date)
        var totalMinutes: Double = 0
        
        for event in events where event.type == .sleep {
            if let sleepEvent = dataStore.getSleepEvent(id: event.id, for: date),
               sleepEvent.sleepType == .nap {
                // Calculate the duration of the nap
                let duration = sleepEvent.endTime.timeIntervalSince(sleepEvent.date) / 60 // in minutes
                totalMinutes += duration
            }
        }
        
        // If we have no data for this day yet, predict from previous patterns
        if totalMinutes == 0 {
            totalMinutes = predictTotalNapMinutes()
        }
        
        // Convert to hours and format
        let hours = Int(totalMinutes / 60)
        let minutes = Int(totalMinutes.truncatingRemainder(dividingBy: 60))
        
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
    
    private func taskCount() -> Int {
        let events = dataStore.getEvents(for: date)
        return events.filter { $0.type == .task }.count
    }
    
    // Prediction functions
    private func predictTotalMilkVolume() -> Double {
        let calendar = Calendar.current
        var total: Double = 0
        var days = 0
        
        // Look at the last 3 days
        for i in 1...3 {
            if let pastDate = calendar.date(byAdding: .day, value: -i, to: date) {
                let pastEvents = dataStore.getEvents(for: pastDate)
                var dayTotal: Double = 0
                
                for event in pastEvents where event.type == .feed {
                    if let feedEvent = dataStore.getFeedEvent(id: event.id, for: pastDate) {
                        dayTotal += feedEvent.amount
                    }
                }
                
                if dayTotal > 0 {
                    total += dayTotal
                    days += 1
                }
            }
        }
        
        // Return average, or default value if no data
        return days > 0 ? total / Double(days) : 700
    }
    
    private func predictFeedCount() -> Int {
        let calendar = Calendar.current
        var total = 0
        var days = 0
        
        // Look at the last 3 days
        for i in 1...3 {
            if let pastDate = calendar.date(byAdding: .day, value: -i, to: date) {
                let pastEvents = dataStore.getEvents(for: pastDate)
                let feedCount = pastEvents.filter { $0.type == .feed }.count
                
                if feedCount > 0 {
                    total += feedCount
                    days += 1
                }
            }
        }
        
        // Return average, or default value if no data
        return days > 0 ? Int(round(Double(total) / Double(days))) : 5
    }
    
    private func predictNapCount() -> Int {
        let calendar = Calendar.current
        var total = 0
        var days = 0
        
        // Look at the last 3 days
        for i in 1...3 {
            if let pastDate = calendar.date(byAdding: .day, value: -i, to: date) {
                let pastEvents = dataStore.getEvents(for: pastDate)
                let napCount = pastEvents.filter {
                    if $0.type == .sleep,
                       let sleepEvent = dataStore.getSleepEvent(id: $0.id, for: pastDate),
                       sleepEvent.sleepType == .nap {
                        return true
                    }
                    return false
                }.count
                
                if napCount > 0 {
                    total += napCount
                    days += 1
                }
            }
        }
        
        // Return average, or default value if no data
        return days > 0 ? Int(round(Double(total) / Double(days))) : 3
    }
    
    private func predictTotalNapMinutes() -> Double {
        let calendar = Calendar.current
        var totalMinutes: Double = 0
        var days = 0
        
        // Look at the last 3 days
        for i in 1...3 {
            if let pastDate = calendar.date(byAdding: .day, value: -i, to: date) {
                let pastEvents = dataStore.getEvents(for: pastDate)
                var dayTotal: Double = 0
                
                for event in pastEvents where event.type == .sleep {
                    if let sleepEvent = dataStore.getSleepEvent(id: event.id, for: pastDate),
                       sleepEvent.sleepType == .nap {
                        let duration = sleepEvent.endTime.timeIntervalSince(sleepEvent.date) / 60 // in minutes
                        dayTotal += duration
                    }
                }
                
                if dayTotal > 0 {
                    totalMinutes += dayTotal
                    days += 1
                }
            }
        }
        
        // Return average, or default value if no data
        return days > 0 ? totalMinutes / Double(days) : 180 // Default to 3 hours
    }
    
    private func getDailyTip() -> String {
        let tips = [
            "Most babies need 12-16 hours of sleep in a 24-hour period",
            "Try to keep nap times consistent each day",
            "Babies typically take 2-4 naps per day, depending on age",
            "A bedtime routine helps signal that it's time to sleep",
            "Watch for sleep cues like rubbing eyes or yawning",
            "Cooler room temperatures (68-72°F) can help improve sleep",
            "Try to put baby down drowsy but still awake",
            "Short naps (20-30 min) might indicate overtiredness"
        ]
        
        // Select a tip based on date to ensure consistency
        let dayOfYear = Calendar.current.ordinality(of: .day, in: .year, for: date) ?? 0
        return tips[dayOfYear % tips.count]
    }
}

// Feed Summary Card
struct FeedSummaryCard: View {
    @EnvironmentObject var dataStore: DataStore
    let date: Date
    
    var body: some View {
        VStack {
            Image(systemName: "cup.and.saucer.fill")
                .font(.system(size: 32))
                .foregroundColor(.blue)
                .padding(.bottom, 5)
            
            Text("\(totalMilkVolume()) ml")
                .font(.title3)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
            
            Text("\(feedCount()) feeds")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            HStack(spacing: 15) {
                VStack {
                    Text("Avg. per feed")
                    Text("\(avgPerFeed()) ml")
                        .fontWeight(.medium)
                }
                .font(.caption)
                .padding(.top, 5)
                
                Divider()
                    .frame(height: 30)
                
                VStack {
                    Text("Schedule")
                    Text("Every \(feedInterval()) hrs")
                        .fontWeight(.medium)
                }
                .font(.caption)
                .padding(.top, 5)
            }
            .padding(.top, 8)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color.blue.opacity(0.1))
        .cornerRadius(16)
    }
    
    private func totalMilkVolume() -> Int {
        let events = dataStore.getEvents(for: date)
        var total: Double = 0
        
        for event in events where event.type == .feed {
            if let feedEvent = dataStore.getFeedEvent(id: event.id, for: date) {
                total += feedEvent.amount
            }
        }
        
        // If we have no data for this day yet, predict from last 3 days
        if total == 0 {
            total = predictTotalMilkVolume()
        }
        
        return Int(total)
    }
    
    private func feedCount() -> Int {
        let events = dataStore.getEvents(for: date)
        let feedEvents = events.filter { $0.type == .feed }
        
        // If we have no data for this day yet, predict from previous patterns
        if feedEvents.isEmpty {
            return predictFeedCount()
        }
        
        return feedEvents.count
    }
    
    private func avgPerFeed() -> Int {
        let total = Double(totalMilkVolume())
        let count = Double(feedCount())
        guard count > 0 else { return 0 }
        return Int(total / count)
    }
    
    private func feedInterval() -> String {
        let wakeComponents = Calendar.current.dateComponents([.hour, .minute], from: dataStore.baby.wakeTime)
        let bedComponents = Calendar.current.dateComponents([.hour, .minute], from: dataStore.baby.bedTime)
        
        let wakeHour = wakeComponents.hour ?? 7
        let bedHour = bedComponents.hour ?? 19
        
        // Calculate awake hours
        var awakeHours = bedHour - wakeHour
        if awakeHours < 0 { awakeHours += 24 }
        
        let count = Double(feedCount())
        guard count > 1 else { return "3" }
        
        // Calculate average interval between feeds
        let interval = Double(awakeHours) / (count - 1)
        return String(format: "%.1f", interval)
    }
    
    // Prediction methods
    private func predictTotalMilkVolume() -> Double {
        let calendar = Calendar.current
        var total: Double = 0
        var days = 0
        
        // Look at the last 3 days
        for i in 1...3 {
            if let pastDate = calendar.date(byAdding: .day, value: -i, to: date) {
                let pastEvents = dataStore.getEvents(for: pastDate)
                var dayTotal: Double = 0
                
                for event in pastEvents where event.type == .feed {
                    if let feedEvent = dataStore.getFeedEvent(id: event.id, for: pastDate) {
                        dayTotal += feedEvent.amount
                    }
                }
                
                if dayTotal > 0 {
                    total += dayTotal
                    days += 1
                }
            }
        }
        
        // Return average, or default value if no data
        return days > 0 ? total / Double(days) : 700
    }
    
    private func predictFeedCount() -> Int {
        let calendar = Calendar.current
        var total = 0
        var days = 0
        
        // Look at the last 3 days
        for i in 1...3 {
            if let pastDate = calendar.date(byAdding: .day, value: -i, to: date) {
                let pastEvents = dataStore.getEvents(for: pastDate)
                let feedCount = pastEvents.filter { $0.type == .feed }.count
                
                if feedCount > 0 {
                    total += feedCount
                    days += 1
                }
            }
        }
        
        // Return average, or default value if no data
        return days > 0 ? Int(round(Double(total) / Double(days))) : 5
    }
}

// Sleep Summary Card
struct SleepSummaryCard: View {
    @EnvironmentObject var dataStore: DataStore
    let date: Date
    
    var body: some View {
        VStack {
            Image(systemName: "moon.zzz.fill")
                .font(.system(size: 32))
                .foregroundColor(.purple)
                .padding(.bottom, 5)
            
            Text(totalNapHours())
                .font(.title3)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
            
            Text("\(napCount()) naps")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            HStack(spacing: 15) {
                VStack {
                    Text("Avg. nap length")
                    Text(averageNapDuration())
                        .fontWeight(.medium)
                }
                .font(.caption)
                .padding(.top, 5)
                
                Divider()
                    .frame(height: 30)
                
                VStack {
                    Text("Next nap")
                    Text(nextNapTime())
                        .fontWeight(.medium)
                }
                .font(.caption)
                .padding(.top, 5)
            }
            .padding(.top, 8)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color.purple.opacity(0.1))
        .cornerRadius(16)
    }
    
    private func napCount() -> Int {
        let events = dataStore.getEvents(for: date)
        let napEvents = events.filter {
            if $0.type == .sleep,
               let sleepEvent = dataStore.getSleepEvent(id: $0.id, for: date),
               sleepEvent.sleepType == .nap {
                return true
            }
            return false
        }
        
        // If we have no data for this day yet, predict from previous patterns
        if napEvents.isEmpty {
            return predictNapCount()
        }
        
        return napEvents.count
    }
    
    private func totalNapMinutes() -> Double {
        let events = dataStore.getEvents(for: date)
        var totalMinutes: Double = 0
        
        for event in events where event.type == .sleep {
            if let sleepEvent = dataStore.getSleepEvent(id: event.id, for: date),
               sleepEvent.sleepType == .nap {
                // Calculate the duration of the nap
                let duration = sleepEvent.endTime.timeIntervalSince(sleepEvent.date) / 60 // in minutes
                totalMinutes += duration
            }
        }
        
        // If we have no data for this day yet, predict from previous patterns
        if totalMinutes == 0 {
            totalMinutes = predictTotalNapMinutes()
        }
        
        return totalMinutes
    }
    
    private func totalNapHours() -> String {
        let totalMinutes = totalNapMinutes()
        
        // Convert to hours and format
        let hours = Int(totalMinutes / 60)
        let minutes = Int(totalMinutes.truncatingRemainder(dividingBy: 60))
        
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
    
    private func averageNapDuration() -> String {
        let totalMins = totalNapMinutes()
        let count = Double(napCount())
        
        if count == 0 { return "30m" }
        
        let avgMinutes = totalMins / count
        let hours = Int(avgMinutes / 60)
        let minutes = Int(avgMinutes.truncatingRemainder(dividingBy: 60))
        
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
    
    private func nextNapTime() -> String {
        // Only applicable for today or future days
        if Calendar.current.isDateInToday(date) || date > Date() {
            let events = dataStore.getEvents(for: date)
            let now = Date()
            
            // Find the next nap after current time
            let upcomingNaps = events.filter {
                if $0.type == .sleep,
                   let sleepEvent = dataStore.getSleepEvent(id: $0.id, for: date),
                   sleepEvent.sleepType == .nap,
                   sleepEvent.date > now,
                   !sleepEvent.isOngoing {
                    return true
                }
                return false
            }.sorted { $0.date < $1.date }
            
            if let nextNap = upcomingNaps.first {
                let formatter = DateFormatter()
                formatter.timeStyle = .short
                return formatter.string(from: nextNap.date)
            }
        }
        
        return "N/A"
    }
    
    // Prediction methods
    private func predictNapCount() -> Int {
        let calendar = Calendar.current
        var total = 0
        var days = 0
        
        // Look at the last 3 days
        for i in 1...3 {
            if let pastDate = calendar.date(byAdding: .day, value: -i, to: date) {
                let pastEvents = dataStore.getEvents(for: pastDate)
                let napCount = pastEvents.filter {
                    if $0.type == .sleep,
                       let sleepEvent = dataStore.getSleepEvent(id: $0.id, for: pastDate),
                       sleepEvent.sleepType == .nap {
                        return true
                    }
                    return false
                }.count
                
                if napCount > 0 {
                    total += napCount
                    days += 1
                }
            }
        }
        
        // Return average, or default value if no data
        return days > 0 ? Int(round(Double(total) / Double(days))) : 3
    }
    
    private func predictTotalNapMinutes() -> Double {
        let calendar = Calendar.current
        var totalMinutes: Double = 0
        var days = 0
        
        // Look at the last 3 days
        for i in 1...3 {
            if let pastDate = calendar.date(byAdding: .day, value: -i, to: date) {
                let pastEvents = dataStore.getEvents(for: pastDate)
                var dayTotal: Double = 0
                
                for event in pastEvents where event.type == .sleep {
                    if let sleepEvent = dataStore.getSleepEvent(id: event.id, for: pastDate),
                       sleepEvent.sleepType == .nap {
                        let duration = sleepEvent.endTime.timeIntervalSince(sleepEvent.date) / 60 // in minutes
                        dayTotal += duration
                    }
                }
                
                if dayTotal > 0 {
                    totalMinutes += dayTotal
                    days += 1
                }
            }
        }
        
        // Return average, or default value if no data
        return days > 0 ? totalMinutes / Double(days) : 180 // Default to 3 hours
    }
}

// Tasks Summary Card
struct TaskSummaryCard: View {
    @EnvironmentObject var dataStore: DataStore
    let date: Date
    
    var body: some View {
        VStack {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 32))
                .foregroundColor(.green)
                .padding(.bottom, 5)
            
            Text("\(taskCount()) tasks")
                .font(.title3)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
            
            Text("\(completedTaskCount()) completed")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            HStack(spacing: 15) {
                VStack {
                    Text("High priority")
                    Text("\(highPriorityCount())")
                        .fontWeight(.medium)
                }
                .font(.caption)
                .padding(.top, 5)
                
                Divider()
                    .frame(height: 30)
                
                VStack {
                    Text("Next task")
                    Text(nextTaskTime())
                        .fontWeight(.medium)
                }
                .font(.caption)
                .padding(.top, 5)
            }
            .padding(.top, 8)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color.green.opacity(0.1))
        .cornerRadius(16)
    }
    
    private func taskCount() -> Int {
        let events = dataStore.getEvents(for: date)
        return events.filter { $0.type == .task }.count
    }
    
    private func completedTaskCount() -> Int {
        let events = dataStore.getEvents(for: date).filter { $0.type == .task }
        var completedCount = 0
        
        for event in events {
            if let taskEvent = dataStore.getTaskEvent(id: event.id, for: date),
               taskEvent.completed {
                completedCount += 1
            }
        }
        
        return completedCount
    }
    
    private func highPriorityCount() -> Int {
        let events = dataStore.getEvents(for: date).filter { $0.type == .task }
        var highPriorityCount = 0
        
        for event in events {
            if let taskEvent = dataStore.getTaskEvent(id: event.id, for: date),
               taskEvent.priority == .high {
                highPriorityCount += 1
            }
        }
        
        return highPriorityCount
    }
    
    private func nextTaskTime() -> String {
        // Only applicable for today or future days
        if Calendar.current.isDateInToday(date) || date > Date() {
            let events = dataStore.getEvents(for: date)
            let now = Date()
            
            // Find the next task after current time that's not completed
            let upcomingTasks = events.filter {
                if $0.type == .task,
                   let taskEvent = dataStore.getTaskEvent(id: $0.id, for: date),
                   taskEvent.date > now,
                   !taskEvent.completed {
                    return true
                }
                return false
            }.sorted { $0.date < $1.date }
            
            if let nextTask = upcomingTasks.first {
                let formatter = DateFormatter()
                formatter.timeStyle = .short
                return formatter.string(from: nextTask.date)
            }
        }
        
        return "N/A"
    }
}

struct NapControlsView: View {
    let sleepEvent: SleepEvent
    let date: Date
    let isPaused: Bool
    let onPauseTapped: () -> Void
    let onStopTapped: () -> Void
    
    // Very important: This is a read-only view that directly uses isPaused prop
    // It doesn't maintain its own state for isPaused
    
    @State private var elapsedTime: TimeInterval = 0
    @State private var timer: Timer? = nil
    @State private var displayTime: String = "00:00"
    
    var body: some View {
        VStack {
            Text("Nap")
                .font(.headline)
                .padding(.bottom, 5)
            
            Text(displayTime)
                .font(.system(size: 24, weight: .bold, design: .monospaced))
                .foregroundColor(isPaused ? .orange : .primary)
                .padding(.bottom, 10)
            
            HStack(spacing: 20) {
                // The pause/play button
                Button(action: onPauseTapped) {
                    ZStack {
                        Circle()
                            .fill(Color.blue.opacity(0.2))
                            .frame(width: 60, height: 60)
                        
                        // CRITICAL: This must use the isPaused prop directly
                        Image(systemName: isPaused ? "play.fill" : "pause.fill")
                            .font(.title2)
                            .foregroundColor(.blue)
                    }
                }
                
                Button(action: onStopTapped) {
                    ZStack {
                        Circle()
                            .fill(Color.red.opacity(0.2))
                            .frame(width: 60, height: 60)
                        
                        Image(systemName: "stop.fill")
                            .font(.title2)
                            .foregroundColor(.red)
                    }
                }
            }
        }
        .padding()
        .onAppear {
            //print("NapControlsView appeared with isPaused: \(isPaused)")
            calculateElapsedTime()
            updateDisplayTime()
            
            if !isPaused {
                startTimer()
            }
        }
        .onChange(of: isPaused) { _, newIsPaused in
            //print("NapControlsView isPaused changed to: \(newIsPaused)")
            
            if newIsPaused {
                // Always stop timer when paused
                stopTimer()
            } else {
                // Always start timer when unpaused
                startTimer()
            }
            
            // Always update elapsed time and display
            calculateElapsedTime()
            updateDisplayTime()
        }
        .onDisappear {
            stopTimer()
        }
    }
    
    private func startTimer() {
        // ALWAYS stop existing timer before starting a new one
        stopTimer()
        
        //print("Starting timer")
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            calculateElapsedTime()
            updateDisplayTime()
        }
    }
    
    private func stopTimer() {
        if timer != nil {
            //print("Stopping timer")
            timer?.invalidate()
            timer = nil
        }
    }
    
    private func calculateElapsedTime() {
        let now = Date()
        var totalPauseTime: TimeInterval = 0
        
        // Calculate total pause time from completed intervals
        for interval in sleepEvent.pauseIntervals {
            totalPauseTime += interval.resumeTime.timeIntervalSince(interval.pauseTime)
        }
        
        // If currently paused, add the current pause interval
        if isPaused, let pauseTime = sleepEvent.lastPauseTime {
            totalPauseTime += now.timeIntervalSince(pauseTime)
        }
        
        // Calculate total elapsed time
        elapsedTime = now.timeIntervalSince(sleepEvent.date) - totalPauseTime
    }
    
    private func updateDisplayTime() {
        displayTime = formattedElapsedTime()
    }
    
    private func formattedElapsedTime() -> String {
        let hours = Int(elapsedTime) / 3600
        let minutes = (Int(elapsedTime) % 3600) / 60
        let seconds = Int(elapsedTime) % 60
        
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%02d:%02d", minutes, seconds)
        }
    }
}
