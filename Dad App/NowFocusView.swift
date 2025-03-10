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
    
    // A single local state to track UI updates
    @State private var localIsPaused: Bool = false
    @State private var localTimer: Timer? = nil
    @State private var displayTime: String = "00:00"
    
    var body: some View {
        ZStack {
            // Content based on active event and date
            if let activeEvent = currentActiveEvent, activeEvent.type == .sleep,
               let sleepEvent = dataStore.getSleepEvent(id: activeEvent.id, for: date),
               sleepEvent.sleepType == .nap {
                
                VStack {
                    Text("Nap")
                        .font(.headline)
                        .padding(.bottom, 5)
                    
                    Text(displayTime)
                        .font(.system(size: 24, weight: .bold, design: .monospaced))
                        .foregroundColor(localIsPaused ? .orange : .primary)
                        .padding(.bottom, 10)
                    
                    HStack(spacing: 20) {
                        // SINGLE BUTTON - either pause or play
                        Button(action: {
                            togglePause(activeEvent: activeEvent, sleepEvent: sleepEvent)
                        }) {
                            ZStack {
                                Circle()
                                    .fill(Color.blue.opacity(0.2))
                                    .frame(width: 60, height: 60)
                                
                                // Only one icon should be visible
                                if localIsPaused {
                                    Image(systemName: "play.fill")
                                        .font(.title2)
                                        .foregroundColor(.blue)
                                } else {
                                    Image(systemName: "pause.fill")
                                        .font(.title2)
                                        .foregroundColor(.blue)
                                }
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
                    // Initialize our local state from the model
                    localIsPaused = activeEvent.isPaused
                    updateDisplayTime(sleepEvent: sleepEvent)
                    
                    // Only start timer if not paused
                    if !localIsPaused {
                        startTimer(sleepEvent: sleepEvent)
                    }
                }
                
            } else if Calendar.current.isDateInToday(date) {
                // Show the next upcoming event when no active event and it's today
                NextEventInfoView(date: date)
                    .environmentObject(dataStore)
            } else {
                // Show daily summary for future dates
                FutureDateSummaryView(date: date)
                    .environmentObject(dataStore)
            }
            
            // For dates after bedtime, show a completion message
            if Calendar.current.isDateInToday(date) && isAfterBedtime() {
                DayCompletionView()
            }
        }
        .onChange(of: currentActiveEvent) { _, newActiveEvent in
            // When active event changes, update our local state
            if let newEvent = newActiveEvent,
               let sleepEvent = dataStore.getSleepEvent(id: newEvent.id, for: date) {
                localIsPaused = newEvent.isPaused
                updateDisplayTime(sleepEvent: sleepEvent)
                
                // Manage timer based on pause state
                if localIsPaused {
                    stopTimer()
                } else {
                    startTimer(sleepEvent: sleepEvent)
                }
            } else {
                // No active event, stop timer
                stopTimer()
            }
        }
        .onDisappear {
            stopTimer()
        }
    }
    
    private func startTimer(sleepEvent: SleepEvent) {
        // Stop any existing timer first
        stopTimer()
        
        print("Starting nap timer")
        localTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            updateDisplayTime(sleepEvent: sleepEvent)
        }
    }
    
    private func stopTimer() {
        if localTimer != nil {
            print("Stopping nap timer")
            localTimer?.invalidate()
            localTimer = nil
        }
    }
    
    private func updateDisplayTime(sleepEvent: SleepEvent) {
        let elapsedTime = calculateElapsedTime(sleepEvent: sleepEvent)
        
        let hours = Int(elapsedTime) / 3600
        let minutes = (Int(elapsedTime) % 3600) / 60
        let seconds = Int(elapsedTime) % 60
        
        if hours > 0 {
            displayTime = String(format: "%d:%02d:%02d", hours, minutes, seconds)
        } else {
            displayTime = String(format: "%02d:%02d", minutes, seconds)
        }
    }
    
    private func calculateElapsedTime(sleepEvent: SleepEvent) -> TimeInterval {
        let now = Date()
        var totalPauseTime: TimeInterval = 0
        
        // Calculate total pause time from completed intervals
        for interval in sleepEvent.pauseIntervals {
            totalPauseTime += interval.resumeTime.timeIntervalSince(interval.pauseTime)
        }
        
        // If currently paused, add the current pause interval
        if localIsPaused, let pauseTime = sleepEvent.lastPauseTime {
            totalPauseTime += now.timeIntervalSince(pauseTime)
        }
        
        // Calculate total elapsed time
        return now.timeIntervalSince(sleepEvent.date) - totalPauseTime
    }
    
    private func togglePause(activeEvent: ActiveEvent, sleepEvent: SleepEvent) {
        // Toggle our local state first
        localIsPaused = !localIsPaused
        print("Toggling pause state to: \(localIsPaused)")
        
        // Update timer immediately based on new state
        if localIsPaused {
            stopTimer()
        } else {
            startTimer(sleepEvent: sleepEvent)
        }
        
        // Now update the model with the new state
        let now = Date()
        var updatedActiveEvent = activeEvent
        var updatedSleepEvent = sleepEvent
        
        if localIsPaused {
            // Pausing
            updatedActiveEvent.isPaused = true
            updatedActiveEvent.lastPauseTime = now
            
            updatedSleepEvent.isPaused = true
            updatedSleepEvent.lastPauseTime = now
            
            // Haptic feedback for pause
            let generator = UIImpactFeedbackGenerator(style: .medium)
            generator.impactOccurred()
        } else {
            // Resuming
            if let pauseTime = activeEvent.lastPauseTime {
                let newInterval = PauseInterval(pauseTime: pauseTime, resumeTime: now)
                
                updatedActiveEvent.pauseIntervals.append(newInterval)
                updatedSleepEvent.pauseIntervals.append(newInterval)
            }
            
            updatedActiveEvent.isPaused = false
            updatedActiveEvent.lastPauseTime = nil
            
            updatedSleepEvent.isPaused = false
            updatedSleepEvent.lastPauseTime = nil
            
            // Haptic feedback for resume
            let generator = UIImpactFeedbackGenerator(style: .light)
            generator.impactOccurred()
        }
        
        // Update the data store and active event
        updatedSleepEvent.actualSleepDuration = calculateElapsedTime(sleepEvent: sleepEvent)
        dataStore.updateSleepEvent(updatedSleepEvent, for: date)
        
        // Very important - replace the entire activeEvent object
        currentActiveEvent = updatedActiveEvent
        
        // Force an immediate update of the display time
        updateDisplayTime(sleepEvent: updatedSleepEvent)
        
        // Notify other components of the change
        NotificationCenter.default.post(
            name: NSNotification.Name("NapPauseStateChanged"),
            object: updatedSleepEvent.id
        )
    }
    
    private func stopNap(activeEvent: ActiveEvent, sleepEvent: SleepEvent) {
        var updatedSleepEvent = sleepEvent
        
        // Set the end time to now
        let now = Date()
        updatedSleepEvent.endTime = now
        
        // Save actual sleep duration
        updatedSleepEvent.actualSleepDuration = calculateElapsedTime(sleepEvent: sleepEvent)
        
        // Save pause intervals for record-keeping
        updatedSleepEvent.pauseIntervals = activeEvent.pauseIntervals
        
        // Mark as no longer ongoing
        updatedSleepEvent.isOngoing = false
        updatedSleepEvent.isPaused = false
        updatedSleepEvent.lastPauseTime = nil
        
        // Stop our timer
        stopTimer()
        
        // Update the data store
        dataStore.updateSleepEvent(updatedSleepEvent, for: date)
        
        // Print debug info
        print("Stopped nap event: \(updatedSleepEvent.id)")
        
        // Post notification to update UI
        NotificationCenter.default.post(name: NSNotification.Name("NapStopped"), object: updatedSleepEvent.id)
        
        // Clear the active event
        currentActiveEvent = nil
    }
    
    private func isAfterBedtime() -> Bool {
        let now = Date()
        
        // Find the actual bedtime event if it exists, otherwise use the default from baby settings
        let bedtimeEvent = dataStore.findBedtimeEvent(for: date)
        let bedTime = bedtimeEvent?.date ?? dataStore.baby.bedTime
        
        // Get current time components
        let calendar = Calendar.current
        var nowComponents = calendar.dateComponents([.hour, .minute], from: now)
        
        // Get bedtime components
        let bedComponents = calendar.dateComponents([.hour, .minute], from: bedTime)
        
        // Convert both to minutes since midnight for comparison
        let nowMinutes = (nowComponents.hour ?? 0) * 60 + (nowComponents.minute ?? 0)
        let bedMinutes = (bedComponents.hour ?? 0) * 60 + (bedComponents.minute ?? 0)
        
        return nowMinutes >= bedMinutes
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
                print("Received EventDataChanged notification - refreshing next event view")
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
                print("Updated next event: \(titleForEvent(new.event)) in \(formatTimeRemaining(new.timeRemaining))")
            }
        } else {
            // Either we had no event before or we have none now
            nextEvent = newNextEvent
            
            if let next = nextEvent {
                print("Found new next event: \(titleForEvent(next.event)) in \(formatTimeRemaining(next.timeRemaining))")
            } else {
                print("No upcoming events found")
            }
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
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.9))
                .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 4)
        )
        .transition(.opacity)
    }
}

// New component for showing summaries for future dates
struct FutureDateSummaryView: View {
    @EnvironmentObject var dataStore: DataStore
    let date: Date
    
    var body: some View {
        VStack(spacing: 15) {
            Text("Plan for \(formattedDate())")
                .font(.headline)
                .foregroundColor(.gray)
            
            HStack(spacing: 20) {
                // Feed summary
                VStack {
                    Image(systemName: "cup.and.saucer.fill")
                        .font(.title)
                        .foregroundColor(.blue)
                    
                    Text("\(totalMilkVolume()) ml")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    
                    Text("\(feedCount()) feeds")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(width: 80)
                
                // Sleep summary
                VStack {
                    Image(systemName: "moon.zzz.fill")
                        .font(.title)
                        .foregroundColor(.purple)
                    
                    Text("\(totalNapHours())")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    
                    Text("\(napCount()) naps")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(width: 80)
                
                // Tasks summary (if implemented)
                VStack {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title)
                        .foregroundColor(.green)
                    
                    Text("\(taskCount())")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    
                    Text("tasks")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(width: 80)
            }
            
            // Show a tip based on recent data
            Text(getDailyTip())
                .font(.subheadline)
                .foregroundColor(.primary)
                .padding()
                .background(Color.blue.opacity(0.1))
                .cornerRadius(8)
                .padding(.top, 5)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(UIColor.systemBackground).opacity(0.9))
                .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 4)
        )
    }
    
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
            print("NapControlsView appeared with isPaused: \(isPaused)")
            calculateElapsedTime()
            updateDisplayTime()
            
            if !isPaused {
                startTimer()
            }
        }
        .onChange(of: isPaused) { _, newIsPaused in
            print("NapControlsView isPaused changed to: \(newIsPaused)")
            
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
        
        print("Starting timer")
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            calculateElapsedTime()
            updateDisplayTime()
        }
    }
    
    private func stopTimer() {
        if timer != nil {
            print("Stopping timer")
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
