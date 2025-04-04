//
//  DataStore.swift
//  Dad App
//
//  Created by Ashley Davison on 06/03/2025.
//

import Foundation
import Combine
import UIKit // Added to access UIImpactFeedbackGenerator

class DataStore: ObservableObject {
    private let babyKey = "baby"
    private let eventsKey = "events"
    private let goalEventsKey = "goalEvents"
    private let feedEventsKey = "feedEvents"
    private let sleepEventsKey = "sleepEvents"
    private let taskEventsKey = "taskEvents"
    
    private var deletedEventsCache: [UUID: DeletedEventState] = [:]
    private var deletionTimers: [UUID: Timer] = [:]
    
    @Published var baby: Baby
    @Published var events: [String: [Event]] = [:]
    @Published var feedEvents: [String: [FeedEvent]] = [:]
    @Published var sleepEvents: [String: [SleepEvent]] = [:]
    @Published var taskEvents: [String: [TaskEvent]] = [:]
    @Published var goalEvents: [String: [GoalEvent]] = [:]
    @Published var isPastDateEditingEnabled: Bool = false
    
    // For undo/redo functionality
    var lastEventStates: [EventState] = [] // Stack of states for undo
    var redoEventStates: [EventState] = [] // Stack of states for redo
    
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        // Load baby data
        if let data = UserDefaults.standard.data(forKey: babyKey),
           let baby = try? JSONDecoder().decode(Baby.self, from: data) {
            self.baby = baby
        } else {
            // Default baby
            self.baby = Baby(name: "Max")
        }
        
        // Load events
        if let data = UserDefaults.standard.data(forKey: eventsKey),
           let events = try? JSONDecoder().decode([String: [Event]].self, from: data) {
            self.events = events
        }
        
        if let data = UserDefaults.standard.data(forKey: goalEventsKey),
           let goalEvents = try? JSONDecoder().decode([String: [GoalEvent]].self, from: data) {
            self.goalEvents = goalEvents
        }
        
        // Load feed events
        if let data = UserDefaults.standard.data(forKey: feedEventsKey),
           let feedEvents = try? JSONDecoder().decode([String: [FeedEvent]].self, from: data) {
            self.feedEvents = feedEvents
        }
        
        // Load sleep events
        if let data = UserDefaults.standard.data(forKey: sleepEventsKey),
           let sleepEvents = try? JSONDecoder().decode([String: [SleepEvent]].self, from: data) {
            self.sleepEvents = sleepEvents
        }
        
        if let data = UserDefaults.standard.data(forKey: taskEventsKey),
           let taskEvents = try? JSONDecoder().decode([String: [TaskEvent]].self, from: data) {
            self.taskEvents = taskEvents
        }
        
        // Save when data changes
        $baby
            .sink { [weak self] baby in
                if let encoded = try? JSONEncoder().encode(baby) {
                    UserDefaults.standard.set(encoded, forKey: self?.babyKey ?? "")
                }
            }
            .store(in: &cancellables)
        
        $events
            .sink { [weak self] events in
                if let encoded = try? JSONEncoder().encode(events) {
                    UserDefaults.standard.set(encoded, forKey: self?.eventsKey ?? "")
                }
            }
            .store(in: &cancellables)
        
        $goalEvents
            .sink { [weak self] goalEvents in
                if let encoded = try? JSONEncoder().encode(goalEvents) {
                    UserDefaults.standard.set(encoded, forKey: self?.goalEventsKey ?? "")
                }
            }
            .store(in: &cancellables)
        
        $feedEvents
            .sink { [weak self] feedEvents in
                if let encoded = try? JSONEncoder().encode(feedEvents) {
                    UserDefaults.standard.set(encoded, forKey: self?.feedEventsKey ?? "")
                }
            }
            .store(in: &cancellables)
        
        $sleepEvents
            .sink { [weak self] sleepEvents in
                if let encoded = try? JSONEncoder().encode(sleepEvents) {
                    UserDefaults.standard.set(encoded, forKey: self?.sleepEventsKey ?? "")
                }
            }
            .store(in: &cancellables)
        
        $taskEvents
            .sink { [weak self] taskEvents in
                if let encoded = try? JSONEncoder().encode(taskEvents) {
                    UserDefaults.standard.set(encoded, forKey: self?.taskEventsKey ?? "")
                }
            }
            .store(in: &cancellables)
    }
    
    func isEditingAllowed(for date: Date) -> Bool {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let checkDate = calendar.startOfDay(for: date)
        
        // If it's today or a future date, editing is always allowed
        if checkDate >= today {
            return true
        }
        
        // For past dates, check if past date editing is enabled
        return isPastDateEditingEnabled
    }
    
    func addGoalEvent(_ event: GoalEvent, for date: Date) {
        let dateString = formatDate(date)
        
        // Add to general events
        var currentEvents = events[dateString] ?? []
        currentEvents.append(event.toEvent())
        events[dateString] = currentEvents
        
        // Add to goal events
        var currentGoalEvents = goalEvents[dateString] ?? []
        currentGoalEvents.append(event)
        goalEvents[dateString] = currentGoalEvents
        
        // Post notification about the new event
        NotificationCenter.default.post(name: NSNotification.Name("EventDataChanged"), object: event.id)
    }
    
    func addFeedEvent(_ event: FeedEvent, for date: Date) {
        let dateString = formatDate(date)
        
        // Add to events
        var currentEvents = events[dateString] ?? []
        currentEvents.append(event.toEvent())
        events[dateString] = currentEvents
        
        // Add to feed events
        var currentFeedEvents = feedEvents[dateString] ?? []
        currentFeedEvents.append(event)
        feedEvents[dateString] = currentFeedEvents
        
        // Schedule notification for the event
        NotificationManager.shared.scheduleFeedNotification(for: event)
        
        // Add this line to post a notification about the new event
        NotificationCenter.default.post(name: NSNotification.Name("EventDataChanged"), object: event.id)
    }
    
    
    func addSleepEvent(_ event: SleepEvent, for date: Date) {
        let dateString = formatDate(date)
        
        // Add to events
        var currentEvents = events[dateString] ?? []
        currentEvents.append(event.toEvent())
        events[dateString] = currentEvents
        
        // Add to sleep events
        var currentSleepEvents = sleepEvents[dateString] ?? []
        currentSleepEvents.append(event)
        sleepEvents[dateString] = currentSleepEvents
        
        // Schedule notification for the event
        NotificationManager.shared.scheduleSleepNotification(for: event)
        
        // CRITICAL FIX: If this is an ongoing nap, post a special notification
        if event.isOngoing && event.sleepType == .nap {
            let activeEvent = ActiveEvent.from(sleepEvent: event)
            
            // Post a notification to alert all components of the new active nap
            NotificationCenter.default.post(
                name: NSNotification.Name("SetActiveNap"),
                object: activeEvent
            )
            
            print("DataStore: Posted SetActiveNap notification for new nap \(event.id)")
        }
        
        // Add this line to post a notification about the new event
        NotificationCenter.default.post(name: NSNotification.Name("EventDataChanged"), object: event.id)
    }
    
    func addTaskEvent(_ event: TaskEvent, for date: Date) {
        let dateString = formatDate(date)
        
        // Always ensure past tense title is generated
        var updatedEvent = event
        // Always generate a past tense version regardless of completion status
        updatedEvent.pastTenseTitle = TaskTitleConverter.shared.convertToPastTense(title: event.title)
        
        // Add to general events
        var currentEvents = events[dateString] ?? []
        currentEvents.append(event.toEvent())
        events[dateString] = currentEvents
        
        // Add to task events
        var currentTaskEvents = taskEvents[dateString] ?? []
        currentTaskEvents.append(updatedEvent)
        taskEvents[dateString] = currentTaskEvents
        
        // Post notification about the new event
        NotificationCenter.default.post(name: NSNotification.Name("EventDataChanged"), object: event.id)
    }
    
    func getEvents(for date: Date) -> [Event] {
        let dateString = formatDate(date)
        return events[dateString] ?? []
    }
    
    
    func getGoalEvent(id: UUID, for date: Date) -> GoalEvent? {
        let dateString = formatDate(date)
        return goalEvents[dateString]?.first(where: { $0.id == id })
    }
    
    func getFeedEvent(id: UUID, for date: Date) -> FeedEvent? {
        let dateString = formatDate(date)
        return feedEvents[dateString]?.first(where: { $0.id == id })
    }
    
    func getSleepEvent(id: UUID, for date: Date) -> SleepEvent? {
        let dateString = formatDate(date)
        return sleepEvents[dateString]?.first(where: { $0.id == id })
    }
    
    func getOngoingSleepEvents(for date: Date) -> [SleepEvent] {
        let dateString = formatDate(date)
        return sleepEvents[dateString]?.filter({ $0.isOngoing }) ?? []
    }
    
    func getTaskEvent(id: UUID, for date: Date) -> TaskEvent? {
        let dateString = formatDate(date)
        return taskEvents[dateString]?.first(where: { $0.id == id })
    }
    
    func startNapNow(for date: Date) -> SleepEvent {
        // Create a new nap event starting now
        let now = Date()
        let estimatedEndTime = now.addingTimeInterval(30 * 60) // Default 30 min duration
        
        let napEvent = SleepEvent(
            date: now,
            sleepType: .nap,
            endTime: estimatedEndTime,
            notes: "Started from quick action",
            isTemplate: false,
            isOngoing: true,
            isPaused: false,
            pauseIntervals: []
        )
        
        // Add the nap to the data store
        addSleepEvent(napEvent, for: date)
        
        return napEvent
    }
    
    func stopOngoingNap(_ sleepEvent: SleepEvent, for date: Date) {
        var updatedEvent = sleepEvent
        
        // Calculate effective duration using SleepUtilities for consistency
        let effectiveDuration = SleepUtilities.calculateEffectiveDuration(sleepEvent: sleepEvent)
        
        // Set the actual sleep duration correctly
        updatedEvent.actualSleepDuration = effectiveDuration
        
        // Set the end time to now
        let now = Date()
        updatedEvent.endTime = now
        
        // Mark as no longer ongoing
        updatedEvent.isOngoing = false
        updatedEvent.isPaused = false
        updatedEvent.lastPauseTime = nil
        
        // Save the updated event
        updateSleepEvent(updatedEvent, for: date)
        
        // Log for debugging
        print("DataStore: Stopped nap with duration \(formatDuration(effectiveDuration))")
    }
    
    // Helper method to find the wake event for a given date
    func findWakeEvent(for date: Date) -> SleepEvent? {
        let dateString = formatDate(date)
        let sleepEvents = self.sleepEvents[dateString] ?? []
        return sleepEvents.first(where: { $0.sleepType == .waketime })
    }
    
    // Helper method to find the bedtime event for a given date
    func findBedtimeEvent(for date: Date) -> SleepEvent? {
        let dateString = formatDate(date)
        let sleepEvents = self.sleepEvents[dateString] ?? []
        return sleepEvents.first(where: { $0.sleepType == .bedtime })
    }
    
    // Method to check if a nap should be automatically stopped due to bedtime
    func checkAndStopNapsAtBedtime() {
        let today = Date()
        //let dateString = formatDate(today)
        let ongoingNaps = getOngoingSleepEvents(for: today).filter { $0.sleepType == .nap }
        
        if !ongoingNaps.isEmpty {
            // Get bedtime for today
            let bedtimeEvent = findBedtimeEvent(for: today)
            let bedTime = bedtimeEvent?.date ?? baby.bedTime
            
            // Check if current time is at or past bedtime
            let now = Date()
            let calendar = Calendar.current
            
            // Convert to minutes since midnight for both times
            let nowComponents = calendar.dateComponents([.hour, .minute], from: now)
            let bedComponents = calendar.dateComponents([.hour, .minute], from: bedTime)
            
            let nowMinutes = (nowComponents.hour ?? 0) * 60 + (nowComponents.minute ?? 0)
            let bedMinutes = (bedComponents.hour ?? 0) * 60 + (bedComponents.minute ?? 0)
            
            // Check if current time is at or past bedtime
            if nowMinutes >= bedMinutes {
                // It's bedtime or later, stop all ongoing naps
                for nap in ongoingNaps {
                    stopOngoingNap(nap, for: today)
                    
                    // Post notification for UI update
                    NotificationCenter.default.post(name: NSNotification.Name("NapStoppedDueToBedtime"), object: nap.id)
                }
                
                //print("Auto-stopped \(ongoingNaps.count) ongoing naps due to bedtime")
            }
        }
    }
    
    // Method to validate event times to ensure they're within wake and bedtime
    func validateEventTimes(startTime: Date, endTime: Date, for date: Date) -> (Date, Date) {
        let calendar = Calendar.current
        
        // Get wake and bedtime for constraints
        let wakeEvent = findWakeEvent(for: date)
        let bedtimeEvent = findBedtimeEvent(for: date)
        
        let wakeTime = wakeEvent?.date ?? baby.wakeTime
        let bedTime = bedtimeEvent?.date ?? baby.bedTime
        
        // Extract components for comparison
        let startComponents = calendar.dateComponents([.hour, .minute], from: startTime)
        let endComponents = calendar.dateComponents([.hour, .minute], from: endTime)
        let wakeComponents = calendar.dateComponents([.hour, .minute], from: wakeTime)
        let bedComponents = calendar.dateComponents([.hour, .minute], from: bedTime)
        
        // Convert to minutes since midnight
        let startMinutes = (startComponents.hour ?? 0) * 60 + (startComponents.minute ?? 0)
        let endMinutes = (endComponents.hour ?? 0) * 60 + (endComponents.minute ?? 0)
        let wakeMinutes = (wakeComponents.hour ?? 0) * 60 + (wakeComponents.minute ?? 0)
        let bedMinutes = (bedComponents.hour ?? 0) * 60 + (bedComponents.minute ?? 0)
        
        // Check if bedtime is after midnight
        let isBedtimeAfterMidnight = bedMinutes < wakeMinutes
        
        // Initialize validated times with input times
        var validStartMinutes = startMinutes
        var validEndMinutes = endMinutes
        
        // Validate start time to be after wake time and before bedtime
        if startMinutes < wakeMinutes {
            validStartMinutes = wakeMinutes
        } else if !isBedtimeAfterMidnight && startMinutes > bedMinutes {
            validStartMinutes = bedMinutes
        }
        
        // Validate end time to be after start time and before bedtime
        if validEndMinutes < validStartMinutes {
            // End time must be after start time
            validEndMinutes = validStartMinutes + 15 // Minimum 15 minutes
        }
        
        if !isBedtimeAfterMidnight && validEndMinutes > bedMinutes {
            // End time must be before bedtime (unless bedtime is after midnight)
            validEndMinutes = bedMinutes
        }
        
        // Create new dates with validated times
        var validStartComponents = calendar.dateComponents([.year, .month, .day], from: date)
        validStartComponents.hour = validStartMinutes / 60
        validStartComponents.minute = validStartMinutes % 60
        
        var validEndComponents = calendar.dateComponents([.year, .month, .day], from: date)
        validEndComponents.hour = validEndMinutes / 60
        validEndComponents.minute = validEndMinutes % 60
        
        // Handle the case where endTime wraps to next day
        if isBedtimeAfterMidnight && validEndMinutes < validStartMinutes {
            validEndComponents.day = (validEndComponents.day ?? 0) + 1
        }
        
        let validStartTime = calendar.date(from: validStartComponents) ?? startTime
        let validEndTime = calendar.date(from: validEndComponents) ?? endTime
        
        return (validStartTime, validEndTime)
    }
    
    // Timer to periodically check for naps that should be stopped at bedtime
    // Update the setupBedtimeNapCheckTimer function to also check for day changes
    func setupBedtimeNapCheckTimer() {
        // Check every minute if it's bedtime and if we need to stop any ongoing naps
        let timer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            
            // Check and stop naps at bedtime
            self.checkAndStopNapsAtBedtime()
            
            // CRITICAL FIX: Also ensure today's schedule exists at regular intervals
            if Calendar.current.isDateInToday(Date()) {
                self.ensureTodayScheduleExists()
            }
        }
        
        // Make sure timer runs even when scrolling
        RunLoop.main.add(timer, forMode: .common)
        
        // CRITICAL FIX: Also run these checks immediately
        ensureTodayScheduleExists()
        checkAndStopNapsAtBedtime()
    }
    
    func togglePauseOngoingNap(_ sleepEvent: SleepEvent, for date: Date) {
        var updatedEvent = sleepEvent
        
        if sleepEvent.isPaused {
            // Resume the nap
            updatedEvent.isPaused = false
            
            // Add the pause interval
            if let pauseTime = sleepEvent.lastPauseTime {
                updatedEvent.pauseIntervals.append(PauseInterval(
                    pauseTime: pauseTime,
                    resumeTime: Date()
                ))
            }
            
            updatedEvent.lastPauseTime = nil
        } else {
            // Pause the nap
            updatedEvent.isPaused = true
            updatedEvent.lastPauseTime = Date()
        }
        
        // Save the updated event
        updateSleepEvent(updatedEvent, for: date)
    }
    
    func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
    
    func undoLastChange() {
        guard let lastState = lastEventStates.last else { return }
        
        let calendar = Calendar.current
        let dateComponents = calendar.dateComponents([.year, .month, .day], from: lastState.oldStartTime)
        let date = calendar.date(from: dateComponents) ?? Date()
        
        // Save current state for redo before modifying (only needed for non-deletions)
        if !lastState.isDeletion {
            saveCurrentStateForRedo(eventId: lastState.eventId, for: date)
        }
        
        // Check if this was a deletion
        if lastState.isDeletion {
            // Restore deleted event from cache
            if let deletedState = deletedEventsCache[lastState.eventId] {
                // Restore based on event type
                if deletedState.eventType == .feed, let feedEvent = deletedState.eventData as? FeedEvent {
                    // Add back to feed events
                    if var currentFeedEvents = feedEvents[deletedState.dateString] {
                        currentFeedEvents.append(feedEvent)
                        feedEvents[deletedState.dateString] = currentFeedEvents
                    } else {
                        feedEvents[deletedState.dateString] = [feedEvent]
                    }
                    
                    // Add back to general events
                    if var currentEvents = events[deletedState.dateString] {
                        currentEvents.append(feedEvent.toEvent())
                        events[deletedState.dateString] = currentEvents
                    } else {
                        events[deletedState.dateString] = [feedEvent.toEvent()]
                    }
                    
                    // Re-schedule notification
                    NotificationManager.shared.scheduleFeedNotification(for: feedEvent)
                    
                    // Post notification about event restoration
                    NotificationCenter.default.post(name: NSNotification.Name("EventDataChanged"), object: feedEvent.id)
                    
                    // Cancel the cleanup timer
                    deletionTimers[feedEvent.id]?.invalidate()
                    deletionTimers.removeValue(forKey: feedEvent.id)
                    
                    // Provide haptic feedback for undo
                    let generator = UIImpactFeedbackGenerator(style: .medium)
                    generator.impactOccurred()
                }
                else if deletedState.eventType == .sleep, let sleepEvent = deletedState.eventData as? SleepEvent {
                    // Add back to sleep events
                    if var currentSleepEvents = sleepEvents[deletedState.dateString] {
                        currentSleepEvents.append(sleepEvent)
                        sleepEvents[deletedState.dateString] = currentSleepEvents
                    } else {
                        sleepEvents[deletedState.dateString] = [sleepEvent]
                    }
                    
                    // Add back to general events
                    if var currentEvents = events[deletedState.dateString] {
                        currentEvents.append(sleepEvent.toEvent())
                        events[deletedState.dateString] = currentEvents
                    } else {
                        events[deletedState.dateString] = [sleepEvent.toEvent()]
                    }
                    
                    // Re-schedule notification
                    NotificationManager.shared.scheduleSleepNotification(for: sleepEvent)
                    
                    // Post notification about event restoration
                    NotificationCenter.default.post(name: NSNotification.Name("EventDataChanged"), object: sleepEvent.id)
                    
                    // Cancel the cleanup timer
                    deletionTimers[sleepEvent.id]?.invalidate()
                    deletionTimers.removeValue(forKey: sleepEvent.id)
                    
                    // Provide haptic feedback for undo
                    let generator = UIImpactFeedbackGenerator(style: .medium)
                    generator.impactOccurred()
                }
                else if deletedState.eventType == .task, let taskEvent = deletedState.eventData as? TaskEvent {
                    // Add back to task events
                    if var currentTaskEvents = taskEvents[deletedState.dateString] {
                        currentTaskEvents.append(taskEvent)
                        taskEvents[deletedState.dateString] = currentTaskEvents
                    } else {
                        taskEvents[deletedState.dateString] = [taskEvent]
                    }
                    
                    // Add back to general events
                    if var currentEvents = events[deletedState.dateString] {
                        currentEvents.append(taskEvent.toEvent())
                        events[deletedState.dateString] = currentEvents
                    } else {
                        events[deletedState.dateString] = [taskEvent.toEvent()]
                    }
                    
                    // Re-schedule notification if applicable
                    if let notificationTime = Calendar.current.date(byAdding: .hour, value: -1, to: taskEvent.date) {
                        NotificationManager.shared.scheduleTaskNotification(for: taskEvent, at: notificationTime)
                    }
                    
                    // Post notification about event restoration
                    NotificationCenter.default.post(name: NSNotification.Name("EventDataChanged"), object: taskEvent.id)
                    
                    // Cancel the cleanup timer
                    deletionTimers[taskEvent.id]?.invalidate()
                    deletionTimers.removeValue(forKey: taskEvent.id)
                    
                    // Provide haptic feedback for undo
                    let generator = UIImpactFeedbackGenerator(style: .medium)
                    generator.impactOccurred()
                }
                
                // Create a special redo state for the deletion
                redoEventStates.append(EventState(
                    eventId: lastState.eventId,
                    eventType: lastState.eventType,
                    oldStartTime: lastState.oldStartTime,
                    oldEndTime: lastState.oldEndTime,
                    oldPrepTime: lastState.oldPrepTime,
                    newStartTime: lastState.newStartTime,
                    newEndTime: lastState.newEndTime,
                    newPrepTime: lastState.newPrepTime,
                    isDeletion: true
                ))
            }
        } else {
            // Handle normal (non-deletion) undos as before
            switch lastState.eventType {
            case .feed:
                if let feedEvent = getFeedEvent(id: lastState.eventId, for: date) {
                    // Create a new feed event with the old times
                    let restoredEvent = FeedEvent(
                        id: feedEvent.id,
                        date: lastState.oldStartTime,
                        amount: feedEvent.amount,
                        breastMilkPercentage: feedEvent.breastMilkPercentage,
                        formulaPercentage: feedEvent.formulaPercentage,
                        preparationTime: lastState.oldPrepTime ?? feedEvent.preparationTime,
                        notes: feedEvent.notes,
                        isTemplate: feedEvent.isTemplate
                    )
                    
                    // Update the feed event
                    updateFeedEvent(restoredEvent, for: date)
                    
                    // Provide haptic feedback for undo
                    let generator = UIImpactFeedbackGenerator(style: .medium)
                    generator.impactOccurred()
                }
                
            case .sleep:
                if let sleepEvent = getSleepEvent(id: lastState.eventId, for: date),
                   let oldEndTime = lastState.oldEndTime {
                    // Create a new sleep event with the old times
                    let restoredEvent = SleepEvent(
                        id: sleepEvent.id,
                        date: lastState.oldStartTime,
                        sleepType: sleepEvent.sleepType,
                        endTime: oldEndTime,
                        notes: sleepEvent.notes,
                        isTemplate: sleepEvent.isTemplate,
                        isOngoing: sleepEvent.isOngoing,
                        isPaused: sleepEvent.isPaused,
                        pauseIntervals: sleepEvent.pauseIntervals,
                        lastPauseTime: sleepEvent.lastPauseTime,
                        actualSleepDuration: sleepEvent.actualSleepDuration
                    )
                    
                    // Update the sleep event
                    updateSleepEvent(restoredEvent, for: date)
                    
                    // Provide haptic feedback for undo
                    let generator = UIImpactFeedbackGenerator(style: .medium)
                    generator.impactOccurred()
                }
                
            case .task:
                if let taskEvent = getTaskEvent(id: lastState.eventId, for: date),
                   let oldEndTime = lastState.oldEndTime {
                    // Create a new task event with the old times
                    let restoredEvent = TaskEvent(
                        id: taskEvent.id,
                        date: lastState.oldStartTime,
                        title: taskEvent.title,
                        endTime: oldEndTime,
                        notes: taskEvent.notes,
                        isTemplate: taskEvent.isTemplate,
                        completed: taskEvent.completed,
                        isOngoing: taskEvent.isOngoing
                    )
                    
                    // Update the task event
                    updateTaskEvent(restoredEvent, for: date)
                    
                    // Provide haptic feedback for undo
                    let generator = UIImpactFeedbackGenerator(style: .medium)
                    generator.impactOccurred()
                }
            case .goal: break
            }
        }
        
        // Remove the last event state after using it
        if !lastEventStates.isEmpty {
            lastEventStates.removeLast()
        }
    }
    
    // Add a new function to detect day change and ensure today's schedule exists
    func ensureTodayScheduleExists() {
        let today = Date()
        let dateString = formatDate(today)
        
        // Check if we have any events for today
        if events[dateString]?.isEmpty != false {
            print("DataStore: No events found for today, generating daily schedule")
            generateDailySchedule(for: today)
            
            // Notify observers that event data has changed
            NotificationCenter.default.post(name: NSNotification.Name("EventDataChanged"), object: nil)
        } else {
            // Check if we have wake and bedtime events
            let todaySleepEvents = sleepEvents[dateString] ?? []
            let hasWakeEvent = todaySleepEvents.contains(where: { $0.sleepType == .waketime })
            let hasBedtimeEvent = todaySleepEvents.contains(where: { $0.sleepType == .bedtime })
            
            if !hasWakeEvent || !hasBedtimeEvent {
                print("DataStore: Missing wake or bedtime events for today, updating schedule")
                
                // Only create missing events
                if !hasWakeEvent {
                    createDefaultWakeEvent(for: today)
                }
                
                if !hasBedtimeEvent {
                    createDefaultBedtimeEvent(for: today)
                }
                
                // Notify observers that event data has changed
                NotificationCenter.default.post(name: NSNotification.Name("EventDataChanged"), object: nil)
            }
        }
    }
    
    // Helper methods to create wake and bedtime events for a specific date
    func createDefaultWakeEvent(for date: Date) {
        let calendar = Calendar.current
        var wakeTimeComponents = calendar.dateComponents([.year, .month, .day], from: date)
        let babyWakeTimeComponents = calendar.dateComponents([.hour, .minute], from: baby.wakeTime)
        wakeTimeComponents.hour = babyWakeTimeComponents.hour
        wakeTimeComponents.minute = babyWakeTimeComponents.minute
        
        if let wakeDateTime = calendar.date(from: wakeTimeComponents) {
            let wakeEvent = SleepEvent(
                date: wakeDateTime,
                sleepType: .waketime,
                endTime: wakeDateTime.addingTimeInterval(30 * 60),
                isTemplate: false
            )
            
            // Add the event to the data store
            addSleepEvent(wakeEvent, for: date)
        }
    }
    
    func createDefaultBedtimeEvent(for date: Date) {
        let calendar = Calendar.current
        var bedTimeComponents = calendar.dateComponents([.year, .month, .day], from: date)
        let babyBedTimeComponents = calendar.dateComponents([.hour, .minute], from: baby.bedTime)
        bedTimeComponents.hour = babyBedTimeComponents.hour
        bedTimeComponents.minute = babyBedTimeComponents.minute
        
        if let bedDateTime = calendar.date(from: bedTimeComponents) {
            // End time is the next morning's wake time
            var nextDay = calendar.dateComponents([.year, .month, .day], from: date)
            nextDay.day = (nextDay.day ?? 0) + 1
            var nextWakeTimeComponents = nextDay
            
            let babyWakeTimeComponents = calendar.dateComponents([.hour, .minute], from: baby.wakeTime)
            nextWakeTimeComponents.hour = babyWakeTimeComponents.hour
            nextWakeTimeComponents.minute = babyWakeTimeComponents.minute
            
            let nextWakeDateTime = calendar.date(from: nextWakeTimeComponents) ?? bedDateTime.addingTimeInterval(10 * 3600)
            
            let bedEvent = SleepEvent(
                date: bedDateTime,
                sleepType: .bedtime,
                endTime: nextWakeDateTime,
                isTemplate: false
            )
            
            // Add the event to the data store
            addSleepEvent(bedEvent, for: date)
        }
    }
    
    
    // Redo functionality
    func redoLastChange() {
        guard let redoState = redoEventStates.last else { return }
        
        let calendar = Calendar.current
        let dateComponents = calendar.dateComponents([.year, .month, .day], from: redoState.oldStartTime)
        let date = calendar.date(from: dateComponents) ?? Date()
        
        // Check if this is a deletion redo
        if redoState.isDeletion {
            // Save state for potential undo
            lastEventStates.append(EventState(
                eventId: redoState.eventId,
                eventType: redoState.eventType,
                oldStartTime: redoState.oldStartTime,
                oldEndTime: redoState.oldEndTime,
                oldPrepTime: redoState.oldPrepTime,
                newStartTime: redoState.newStartTime,
                newEndTime: redoState.newEndTime,
                newPrepTime: redoState.newPrepTime,
                isDeletion: true
            ))
            
            // Re-delete the event
            switch redoState.eventType {
            case .feed:
                if let feedEvent = getFeedEvent(id: redoState.eventId, for: date) {
                    // Re-cache the event before re-deletion
                    let deletedState = DeletedEventState(
                        eventId: feedEvent.id,
                        eventType: .feed,
                        date: date,
                        dateString: formatDate(date),
                        eventData: feedEvent
                    )
                    deletedEventsCache[feedEvent.id] = deletedState
                    
                    // Remove from feed events and events collections
                    if var currentFeedEvents = feedEvents[formatDate(date)] {
                        currentFeedEvents.removeAll(where: { $0.id == feedEvent.id })
                        feedEvents[formatDate(date)] = currentFeedEvents
                    }
                    
                    if var currentEvents = events[formatDate(date)] {
                        currentEvents.removeAll(where: { $0.id == feedEvent.id })
                        events[formatDate(date)] = currentEvents
                    }
                    
                    // Cancel notification
                    NotificationManager.shared.cancelNotification(for: feedEvent.id)
                    
                    // Post notification about the event deletion
                    NotificationCenter.default.post(name: NSNotification.Name("EventDataChanged"), object: feedEvent.id)
                    
                    // Schedule removal from cache after delay
                    scheduleDeletionCleanup(eventId: feedEvent.id)
                    
                    // Provide haptic feedback
                    let generator = UIImpactFeedbackGenerator(style: .medium)
                    generator.impactOccurred()
                }
                
            case .sleep:
                if let sleepEvent = getSleepEvent(id: redoState.eventId, for: date) {
                    // Re-cache the event before re-deletion
                    let deletedState = DeletedEventState(
                        eventId: sleepEvent.id,
                        eventType: .sleep,
                        date: date,
                        dateString: formatDate(date),
                        eventData: sleepEvent
                    )
                    deletedEventsCache[sleepEvent.id] = deletedState
                    
                    // Remove from sleep events and events collections
                    if var currentSleepEvents = sleepEvents[formatDate(date)] {
                        currentSleepEvents.removeAll(where: { $0.id == sleepEvent.id })
                        sleepEvents[formatDate(date)] = currentSleepEvents
                    }
                    
                    if var currentEvents = events[formatDate(date)] {
                        currentEvents.removeAll(where: { $0.id == sleepEvent.id })
                        events[formatDate(date)] = currentEvents
                    }
                    
                    // Cancel notification
                    NotificationManager.shared.cancelNotification(for: sleepEvent.id)
                    
                    // Post notification about the event deletion
                    NotificationCenter.default.post(name: NSNotification.Name("EventDataChanged"), object: sleepEvent.id)
                    
                    // Schedule removal from cache after delay
                    scheduleDeletionCleanup(eventId: sleepEvent.id)
                    
                    // Provide haptic feedback
                    let generator = UIImpactFeedbackGenerator(style: .medium)
                    generator.impactOccurred()
                }
                
            case .task:
                if let taskEvent = getTaskEvent(id: redoState.eventId, for: date) {
                    // Re-cache the event before re-deletion
                    let deletedState = DeletedEventState(
                        eventId: taskEvent.id,
                        eventType: .task,
                        date: date,
                        dateString: formatDate(date),
                        eventData: taskEvent
                    )
                    deletedEventsCache[taskEvent.id] = deletedState
                    
                    // Remove from task events and events collections
                    if var currentTaskEvents = taskEvents[formatDate(date)] {
                        currentTaskEvents.removeAll(where: { $0.id == taskEvent.id })
                        taskEvents[formatDate(date)] = currentTaskEvents
                    }
                    
                    if var currentEvents = events[formatDate(date)] {
                        currentEvents.removeAll(where: { $0.id == taskEvent.id })
                        events[formatDate(date)] = currentEvents
                    }
                    
                    // Cancel notification
                    NotificationManager.shared.cancelNotification(for: taskEvent.id)
                    
                    // Post notification about the event deletion
                    NotificationCenter.default.post(name: NSNotification.Name("EventDataChanged"), object: taskEvent.id)
                    
                    // Schedule removal from cache after delay
                    scheduleDeletionCleanup(eventId: taskEvent.id)
                    
                    // Provide haptic feedback
                    let generator = UIImpactFeedbackGenerator(style: .medium)
                    generator.impactOccurred()
                }
            case .goal: break
            }
        } else {
            // Handle non-deletion redos as before
            // Save current state for potential undo before modifying
            saveCurrentStateForUndo(eventId: redoState.eventId, for: date)
            
            switch redoState.eventType {
            case .feed:
                if let feedEvent = getFeedEvent(id: redoState.eventId, for: date) {
                    // Create a new feed event with the redo times
                    let restoredEvent = FeedEvent(
                        id: feedEvent.id,
                        date: redoState.newStartTime,
                        amount: feedEvent.amount,
                        breastMilkPercentage: feedEvent.breastMilkPercentage,
                        formulaPercentage: feedEvent.formulaPercentage,
                        preparationTime: redoState.newPrepTime ?? feedEvent.preparationTime,
                        notes: feedEvent.notes,
                        isTemplate: feedEvent.isTemplate
                    )
                    
                    // Update the feed event
                    updateFeedEvent(restoredEvent, for: date)
                    
                    // Provide haptic feedback for redo
                    let generator = UIImpactFeedbackGenerator(style: .medium)
                    generator.impactOccurred()
                }
                
            case .sleep:
                if let sleepEvent = getSleepEvent(id: redoState.eventId, for: date),
                   let newEndTime = redoState.newEndTime {
                    // Create a new sleep event with the redo times
                    let restoredEvent = SleepEvent(
                        id: sleepEvent.id,
                        date: redoState.newStartTime,
                        sleepType: sleepEvent.sleepType,
                        endTime: newEndTime,
                        notes: sleepEvent.notes,
                        isTemplate: sleepEvent.isTemplate,
                        isOngoing: sleepEvent.isOngoing,
                        isPaused: sleepEvent.isPaused,
                        pauseIntervals: sleepEvent.pauseIntervals,
                        lastPauseTime: sleepEvent.lastPauseTime,
                        actualSleepDuration: sleepEvent.actualSleepDuration
                    )
                    
                    // Update the sleep event
                    updateSleepEvent(restoredEvent, for: date)
                    
                    // Provide haptic feedback for redo
                    let generator = UIImpactFeedbackGenerator(style: .medium)
                    generator.impactOccurred()
                }
                
            case .task:
                if let taskEvent = getTaskEvent(id: redoState.eventId, for: date),
                   let newEndTime = redoState.newEndTime {
                    // Create a new task event with the redo times
                    let restoredEvent = TaskEvent(
                        id: taskEvent.id,
                        date: redoState.newStartTime,
                        title: taskEvent.title,
                        endTime: newEndTime,
                        notes: taskEvent.notes,
                        isTemplate: taskEvent.isTemplate,
                        completed: taskEvent.completed,
                        isOngoing: taskEvent.isOngoing
                    )
                    
                    // Update the task event
                    updateTaskEvent(restoredEvent, for: date)
                    
                    // Provide haptic feedback for redo
                    let generator = UIImpactFeedbackGenerator(style: .medium)
                    generator.impactOccurred()
                }
            case .goal: break
            }
        }
        
        // Remove the redo event state after using it
        if !redoEventStates.isEmpty {
            redoEventStates.removeLast()
        }
    }
    
    private func saveCurrentStateForRedo(eventId: UUID, for date: Date) {
        let calendar = Calendar.current
        let dateComponents = calendar.dateComponents([.year, .month, .day], from: date)
        let dateFormatted = calendar.date(from: dateComponents) ?? date
        
        // Get current event state
        if let feedEvent = getFeedEvent(id: eventId, for: dateFormatted) {
            redoEventStates.append(EventState(
                eventId: eventId,
                eventType: .feed,
                oldStartTime: feedEvent.date, // Current time for potential undo
                oldEndTime: nil,
                oldPrepTime: feedEvent.preparationTime,
                newStartTime: feedEvent.date, // Current time for redo
                newEndTime: nil,
                newPrepTime: feedEvent.preparationTime
            ))
        } else if let sleepEvent = getSleepEvent(id: eventId, for: dateFormatted) {
            redoEventStates.append(EventState(
                eventId: eventId,
                eventType: .sleep,
                oldStartTime: sleepEvent.date, // Current time for potential undo
                oldEndTime: sleepEvent.endTime,
                oldPrepTime: nil,
                newStartTime: sleepEvent.date, // Current time for redo
                newEndTime: sleepEvent.endTime,
                newPrepTime: nil
            ))
        } else if let taskEvent = getTaskEvent(id: eventId, for: dateFormatted) {
            redoEventStates.append(EventState(
                eventId: eventId,
                eventType: .task,
                oldStartTime: taskEvent.date, // Current time for potential undo
                oldEndTime: taskEvent.endTime,
                oldPrepTime: nil,
                newStartTime: taskEvent.date, // Current time for redo
                newEndTime: taskEvent.endTime,
                newPrepTime: nil
            ))
        }
    }
    
    // Save current state for potential undo
    internal func saveCurrentStateForUndo(eventId: UUID, for date: Date) {
        let calendar = Calendar.current
        let dateComponents = calendar.dateComponents([.year, .month, .day], from: date)
        let dateFormatted = calendar.date(from: dateComponents) ?? date
        
        // Get current event state
        if let feedEvent = getFeedEvent(id: eventId, for: dateFormatted) {
            lastEventStates.append(EventState(
                eventId: eventId,
                eventType: .feed,
                oldStartTime: feedEvent.date,
                oldEndTime: nil,
                oldPrepTime: feedEvent.preparationTime,
                newStartTime: feedEvent.date,
                newEndTime: nil,
                newPrepTime: feedEvent.preparationTime
            ))
        } else if let sleepEvent = getSleepEvent(id: eventId, for: dateFormatted) {
            lastEventStates.append(EventState(
                eventId: eventId,
                eventType: .sleep,
                oldStartTime: sleepEvent.date,
                oldEndTime: sleepEvent.endTime,
                oldPrepTime: nil,
                newStartTime: sleepEvent.date,
                newEndTime: sleepEvent.endTime,
                newPrepTime: nil
            ))
        } else if let taskEvent = getTaskEvent(id: eventId, for: dateFormatted) {
            lastEventStates.append(EventState(
                eventId: eventId,
                eventType: .task,
                oldStartTime: taskEvent.date,
                oldEndTime: taskEvent.endTime,
                oldPrepTime: nil,
                newStartTime: taskEvent.date,
                newEndTime: taskEvent.endTime,
                newPrepTime: nil
            ))
        }
    }
    
    func generateDailySchedule(for date: Date) {
        // First check if we already have events for this date
        let dateString = formatDate(date)
        
        var dailyEvents: [Event] = []
        var dailyFeedEvents: [FeedEvent] = []
        var dailySleepEvents: [SleepEvent] = []
        
        // Check if we already have wake and bedtime events
        _ = events[dateString] ?? []
        let existingSleepEvents = sleepEvents[dateString] ?? []
        
        // Filter for existing wake and bedtime events
        let existingWakeEvent = existingSleepEvents.first(where: { $0.sleepType == .waketime })
        let existingBedtimeEvent = existingSleepEvents.first(where: { $0.sleepType == .bedtime })
        
        // Add wake time (use existing if available, otherwise use default from baby settings)
        if let wakeEvent = existingWakeEvent {
            dailyEvents.append(wakeEvent.toEvent())
            dailySleepEvents.append(wakeEvent)
        } else {
            let calendar = Calendar.current
            var wakeTimeComponents = calendar.dateComponents([.year, .month, .day], from: date)
            let babyWakeTimeComponents = calendar.dateComponents([.hour, .minute], from: baby.wakeTime)
            wakeTimeComponents.hour = babyWakeTimeComponents.hour
            wakeTimeComponents.minute = babyWakeTimeComponents.minute
            
            if let wakeDateTime = calendar.date(from: wakeTimeComponents) {
                let wakeEvent = SleepEvent(
                    date: wakeDateTime,
                    sleepType: .waketime,
                    endTime: wakeDateTime.addingTimeInterval(30 * 60),
                    isTemplate: false
                )
                dailyEvents.append(wakeEvent.toEvent())
                dailySleepEvents.append(wakeEvent)
            }
        }
        
        // Add any existing feed events
        let existingFeedEvents = feedEvents[dateString] ?? []
        dailyFeedEvents.append(contentsOf: existingFeedEvents)
        for feedEvent in existingFeedEvents {
            dailyEvents.append(feedEvent.toEvent())
        }
        
        // Add any existing sleep events that aren't wake/bedtime
        for sleepEvent in existingSleepEvents.filter({ $0.sleepType != .waketime && $0.sleepType != .bedtime }) {
            dailyEvents.append(sleepEvent.toEvent())
            dailySleepEvents.append(sleepEvent)
        }
        
        // Add feed templates only if we don't have any feed events yet
        if existingFeedEvents.isEmpty {
            for template in baby.feedTemplates {
                let calendar = Calendar.current
                var feedComponents = calendar.dateComponents([.year, .month, .day], from: date)
                let templateComponents = calendar.dateComponents([.hour, .minute], from: template.date)
                feedComponents.hour = templateComponents.hour
                feedComponents.minute = templateComponents.minute
                
                if let feedDateTime = calendar.date(from: feedComponents) {
                    // Prepare time (1 hour before by default if not set)
                    var prepComponents = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: feedDateTime)
                    let templatePrepComponents = calendar.dateComponents([.hour, .minute], from: template.preparationTime)
                    
                    if templatePrepComponents.hour == 0 && templatePrepComponents.minute == 0 {
                        // Default to 1 hour before
                        prepComponents.hour = (prepComponents.hour ?? 0) - 1
                    } else {
                        prepComponents.hour = templatePrepComponents.hour
                        prepComponents.minute = templatePrepComponents.minute
                    }
                    
                    let prepDateTime = calendar.date(from: prepComponents) ?? feedDateTime.addingTimeInterval(-3600)
                    
                    let feedEvent = FeedEvent(
                        date: feedDateTime,
                        amount: template.amount,
                        breastMilkPercentage: template.breastMilkPercentage,
                        formulaPercentage: template.formulaPercentage,
                        preparationTime: prepDateTime,
                        notes: template.notes,
                        isTemplate: false
                    )
                    dailyEvents.append(feedEvent.toEvent())
                    dailyFeedEvents.append(feedEvent)
                }
            }
            
            // Add sleep templates (only naps, not bedtime) if we don't have any sleep events yet
            // But only add if we don't have regular sleep events (not counting wake/bedtime)
            if existingSleepEvents.filter({ $0.sleepType == .nap }).isEmpty {
                for template in baby.sleepTemplates.filter({ $0.sleepType == .nap }) {
                    let calendar = Calendar.current
                    var sleepComponents = calendar.dateComponents([.year, .month, .day], from: date)
                    let templateComponents = calendar.dateComponents([.hour, .minute], from: template.date)
                    sleepComponents.hour = templateComponents.hour
                    sleepComponents.minute = templateComponents.minute
                    
                    if let sleepDateTime = calendar.date(from: sleepComponents) {
                        // End time
                        var endComponents = calendar.dateComponents([.year, .month, .day], from: date)
                        let templateEndComponents = calendar.dateComponents([.hour, .minute], from: template.endTime)
                        endComponents.hour = templateEndComponents.hour
                        endComponents.minute = templateEndComponents.minute
                        
                        let endDateTime = calendar.date(from: endComponents) ?? sleepDateTime.addingTimeInterval(30 * 60)
                        
                        let sleepEvent = SleepEvent(
                            date: sleepDateTime,
                            sleepType: template.sleepType,
                            endTime: endDateTime,
                            notes: template.notes,
                            isTemplate: false
                        )
                        dailyEvents.append(sleepEvent.toEvent())
                        dailySleepEvents.append(sleepEvent)
                    }
                }
            }
        }
        
        // Add bedtime (use existing if available, otherwise use default from baby settings)
        if let bedtimeEvent = existingBedtimeEvent {
            dailyEvents.append(bedtimeEvent.toEvent())
            dailySleepEvents.append(bedtimeEvent)
        } else {
            let calendar = Calendar.current
            var bedTimeComponents = calendar.dateComponents([.year, .month, .day], from: date)
            let babyBedTimeComponents = calendar.dateComponents([.hour, .minute], from: baby.bedTime)
            bedTimeComponents.hour = babyBedTimeComponents.hour
            bedTimeComponents.minute = babyBedTimeComponents.minute
            
            if let bedDateTime = calendar.date(from: bedTimeComponents) {
                // End time is the next morning's wake time
                var nextDay = calendar.dateComponents([.year, .month, .day], from: date)
                nextDay.day = (nextDay.day ?? 0) + 1
                var nextWakeTimeComponents = nextDay
                
                let babyWakeTimeComponents = calendar.dateComponents([.hour, .minute], from: baby.wakeTime)
                nextWakeTimeComponents.hour = babyWakeTimeComponents.hour
                nextWakeTimeComponents.minute = babyWakeTimeComponents.minute
                
                let nextWakeDateTime = calendar.date(from: nextWakeTimeComponents) ?? bedDateTime.addingTimeInterval(10 * 3600)
                
                let bedEvent = SleepEvent(
                    date: bedDateTime,
                    sleepType: .bedtime,
                    endTime: nextWakeDateTime,
                    isTemplate: false
                )
                dailyEvents.append(bedEvent.toEvent())
                dailySleepEvents.append(bedEvent)
            }
        }
        
        // Save all daily events - replace existing events completely
        // to avoid duplicates
        events[dateString] = dailyEvents
        feedEvents[dateString] = dailyFeedEvents
        sleepEvents[dateString] = dailySleepEvents
        
        // Schedule notifications for all events
        for feedEvent in dailyFeedEvents {
            NotificationManager.shared.scheduleFeedNotification(for: feedEvent)
        }
        
        for sleepEvent in dailySleepEvents {
            NotificationManager.shared.scheduleSleepNotification(for: sleepEvent)
        }
    }
    
    func updateFeedEvent(_ event: FeedEvent, for date: Date) {
        let dateString = formatDate(date)
        
        // Update in events
        if var currentEvents = events[dateString] {
            if let index = currentEvents.firstIndex(where: { $0.id == event.id }) {
                currentEvents[index] = event.toEvent()
                events[dateString] = currentEvents
            }
        }
        
        // Update in feed events
        if var currentFeedEvents = feedEvents[dateString] {
            if let index = currentFeedEvents.firstIndex(where: { $0.id == event.id }) {
                currentFeedEvents[index] = event
                feedEvents[dateString] = currentFeedEvents
                
                // Update notification
                NotificationManager.shared.cancelNotification(for: event.id)
                NotificationManager.shared.scheduleFeedNotification(for: event)
                
                // Add this line to post a notification about the event change
                NotificationCenter.default.post(name: NSNotification.Name("EventDataChanged"), object: event.id)
            }
        }
    }
    
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
    
    
    func updateGoalEvent(_ event: GoalEvent, for date: Date) {
        let dateString = formatDate(date)
        
        // Update in general events
        if var currentEvents = events[dateString] {
            if let index = currentEvents.firstIndex(where: { $0.id == event.id }) {
                currentEvents[index] = event.toEvent()
                events[dateString] = currentEvents
            }
        }
        
        // Update in goal events
        if var currentGoalEvents = goalEvents[dateString] {
            if let index = currentGoalEvents.firstIndex(where: { $0.id == event.id }) {
                currentGoalEvents[index] = event
                goalEvents[dateString] = currentGoalEvents
                
                // Post notification about the event update
                NotificationCenter.default.post(name: NSNotification.Name("EventDataChanged"), object: event.id)
            }
        }
    }

    func updateSleepEvent(_ event: SleepEvent, for date: Date) {
        let dateString = formatDate(date)
        
        // Create a copy to ensure we're preserving all properties
        var eventCopy = event
        
        // Preserve the actual sleep duration as a top priority
        let actualDuration = event.actualSleepDuration
        
        // Update in events
        if var currentEvents = events[dateString] {
            if let index = currentEvents.firstIndex(where: { $0.id == event.id }) {
                currentEvents[index] = event.toEvent()
                events[dateString] = currentEvents
            }
        }
        
        // Update in sleep events
        if var currentSleepEvents = sleepEvents[dateString] {
            if let index = currentSleepEvents.firstIndex(where: { $0.id == event.id }) {
                // Ensure actual duration is preserved
                eventCopy.actualSleepDuration = actualDuration
                currentSleepEvents[index] = eventCopy
                sleepEvents[dateString] = currentSleepEvents
                
                // Update notification
                NotificationManager.shared.cancelNotification(for: event.id)
                NotificationManager.shared.scheduleSleepNotification(for: event)
                
                // Add this line to post a notification about the event change
                NotificationCenter.default.post(name: NSNotification.Name("EventDataChanged"), object: event.id)
            }
        }
    }
    
    func updateTaskEvent(_ event: TaskEvent, for date: Date) {
        let dateString = formatDate(date)
        
        // Always regenerate past tense title
        var updatedEvent = event
        updatedEvent.pastTenseTitle = TaskTitleConverter.shared.convertToPastTense(title: event.title)
        
        // Update in general events
        if var currentEvents = events[dateString] {
            if let index = currentEvents.firstIndex(where: { $0.id == event.id }) {
                currentEvents[index] = event.toEvent()
                events[dateString] = currentEvents
            }
        }
        
        // Update in task events
        if var currentTaskEvents = taskEvents[dateString] {
            if let index = currentTaskEvents.firstIndex(where: { $0.id == event.id }) {
                currentTaskEvents[index] = updatedEvent
                taskEvents[dateString] = currentTaskEvents
                
                // Always cancel existing notifications first
                NotificationManager.shared.cancelNotification(for: event.id)
                
                // Schedule new notification if the task is in the future
                if event.date > Date() {
                    // Schedule task notification at the task time
                    NotificationManager.shared.scheduleTaskNotification(for: updatedEvent, at: updatedEvent.date)
                }
                
                // Post notification about event update
                NotificationCenter.default.post(name: NSNotification.Name("EventDataChanged"), object: event.id)
            }
        }
    }
    
    func deleteGoalEvent(_ event: GoalEvent, for date: Date) {
        let dateString = formatDate(date)
        
        // Cache the event before deletion
        let deletedState = DeletedEventState(
            eventId: event.id,
            eventType: .goal,
            date: date,
            dateString: dateString,
            eventData: event
        )
        deletedEventsCache[event.id] = deletedState
        
        // Save deletion state for undo
        lastEventStates.append(EventState(
            eventId: event.id,
            eventType: .goal,
            oldStartTime: event.date,
            oldEndTime: nil,
            oldPrepTime: nil,
            newStartTime: event.date,
            newEndTime: nil,
            newPrepTime: nil,
            isDeletion: true
        ))
        
        // Delete from general events
        if var currentEvents = events[dateString] {
            currentEvents.removeAll(where: { $0.id == event.id })
            events[dateString] = currentEvents
        }
        
        // Delete from goal events
        if var currentGoalEvents = goalEvents[dateString] {
            currentGoalEvents.removeAll(where: { $0.id == event.id })
            goalEvents[dateString] = currentGoalEvents
            
            // Post notification about the event deletion
            NotificationCenter.default.post(name: NSNotification.Name("EventDataChanged"), object: event.id)
        }
        
        // Schedule removal from cache after delay
        scheduleDeletionCleanup(eventId: event.id)
        
        // Clear the position cache for this event
        NotificationCenter.default.post(name: NSNotification.Name("ClearPositionCache"), object: event.id)
        
        // Provide haptic feedback to confirm deletion
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
    }
    
    
    func deleteFeedEvent(_ event: FeedEvent, for date: Date) {
        let dateString = formatDate(date)
        
        // Cache the event before deletion
        let deletedState = DeletedEventState(
            eventId: event.id,
            eventType: .feed,
            date: date,
            dateString: dateString,
            eventData: event
        )
        deletedEventsCache[event.id] = deletedState
        
        // Save deletion state for undo
        lastEventStates.append(EventState(
            eventId: event.id,
            eventType: .feed,
            oldStartTime: event.date,
            oldEndTime: nil,
            oldPrepTime: event.preparationTime,
            newStartTime: event.date,
            newEndTime: nil,
            newPrepTime: event.preparationTime,
            isDeletion: true
        ))
        
        // Delete from events
        if var currentEvents = events[dateString] {
            currentEvents.removeAll(where: { $0.id == event.id })
            events[dateString] = currentEvents
        }
        
        // Delete from feed events
        if var currentFeedEvents = feedEvents[dateString] {
            currentFeedEvents.removeAll(where: { $0.id == event.id })
            feedEvents[dateString] = currentFeedEvents
            
            // Cancel notification
            NotificationManager.shared.cancelNotification(for: event.id)
            
            // Post notification about the event deletion
            NotificationCenter.default.post(name: NSNotification.Name("EventDataChanged"), object: event.id)
        }
        
        // Schedule removal from cache after delay
        scheduleDeletionCleanup(eventId: event.id)
        
        // Clear the position cache for this event
        NotificationCenter.default.post(name: NSNotification.Name("ClearPositionCache"), object: event.id)
        
        // Provide haptic feedback to confirm deletion
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
    }
    
    func deleteSleepEvent(_ event: SleepEvent, for date: Date) {
        let dateString = formatDate(date)
        
        // Log the deletion operation
        print("DataStore: Deleting sleep event ID \(event.id) for date \(dateString)")
        
        // Cache the event before deletion
        let deletedState = DeletedEventState(
            eventId: event.id,
            eventType: .sleep,
            date: date,
            dateString: dateString,
            eventData: event
        )
        deletedEventsCache[event.id] = deletedState
        
        // Save deletion state for undo
        lastEventStates.append(EventState(
            eventId: event.id,
            eventType: .sleep,
            oldStartTime: event.date,
            oldEndTime: event.endTime,
            oldPrepTime: nil,
            newStartTime: event.date,
            newEndTime: event.endTime,
            newPrepTime: nil,
            isDeletion: true
        ))
        
        // Delete from events
        if var currentEvents = events[dateString] {
            let countBefore = currentEvents.count
            currentEvents.removeAll(where: { $0.id == event.id })
            let countAfter = currentEvents.count
            print("DataStore: Removed \(countBefore - countAfter) entries from events array")
            events[dateString] = currentEvents
        }
        
        // Delete from sleep events
        if var currentSleepEvents = sleepEvents[dateString] {
            let countBefore = currentSleepEvents.count
            currentSleepEvents.removeAll(where: { $0.id == event.id })
            let countAfter = currentSleepEvents.count
            print("DataStore: Removed \(countBefore - countAfter) entries from sleepEvents array")
            sleepEvents[dateString] = currentSleepEvents
            
            // Cancel notification
            NotificationManager.shared.cancelNotification(for: event.id)
            
            // Force UI update by triggering objectWillChange
            objectWillChange.send()
            
            // Provide haptic feedback to confirm deletion
            let generator = UIImpactFeedbackGenerator(style: .medium)
            generator.impactOccurred()
            
            // Post notification about the event deletion
            NotificationCenter.default.post(name: NSNotification.Name("EventDataChanged"), object: event.id)
        }
        
        // Clear the position cache for this event
        NotificationCenter.default.post(name: NSNotification.Name("ClearPositionCache"), object: event.id)
        
        // Schedule removal from cache after delay
        scheduleDeletionCleanup(eventId: event.id)
    }
    
    func deleteTaskEvent(_ event: TaskEvent, for date: Date) {
        let dateString = formatDate(date)
        
        // Cache the event before deletion
        let deletedState = DeletedEventState(
            eventId: event.id,
            eventType: .task,
            date: date,
            dateString: dateString,
            eventData: event
        )
        deletedEventsCache[event.id] = deletedState
        
        // Save deletion state for undo
        lastEventStates.append(EventState(
            eventId: event.id,
            eventType: .task,
            oldStartTime: event.date,
            oldEndTime: event.endTime,
            oldPrepTime: nil,
            newStartTime: event.date,
            newEndTime: event.endTime,
            newPrepTime: nil,
            isDeletion: true
        ))
        
        // Delete from general events
        if var currentEvents = events[dateString] {
            currentEvents.removeAll(where: { $0.id == event.id })
            events[dateString] = currentEvents
        }
        
        // Delete from task events
        if var currentTaskEvents = taskEvents[dateString] {
            currentTaskEvents.removeAll(where: { $0.id == event.id })
            taskEvents[dateString] = currentTaskEvents
            
            // Cancel notification
            NotificationManager.shared.cancelNotification(for: event.id)
            
            // Trigger UI updates
            NotificationCenter.default.post(name: NSNotification.Name("EventDataChanged"), object: event.id)
        }
        
        // Schedule removal from cache after delay
        scheduleDeletionCleanup(eventId: event.id)
        
        // Clear the position cache for this event
        NotificationCenter.default.post(name: NSNotification.Name("ClearPositionCache"), object: event.id)
        
        // Provide haptic feedback to confirm deletion
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
    }
    
    private func scheduleDeletionCleanup(eventId: UUID) {
        // Cancel any existing timer for this event
        deletionTimers[eventId]?.invalidate()
        
        // Create a new timer to permanently delete after delay (10 minutes = 600 seconds)
        let timer = Timer.scheduledTimer(withTimeInterval: 600, repeats: false) { [weak self] _ in
            self?.permanentlyDeleteEvent(eventId: eventId)
        }
        
        // Store the timer
        deletionTimers[eventId] = timer
    }
    
    private func permanentlyDeleteEvent(eventId: UUID) {
        // Remove from cache
        deletedEventsCache.removeValue(forKey: eventId)
        
        // Remove timer
        deletionTimers.removeValue(forKey: eventId)
        
        print("Permanently deleted event ID \(eventId) from cache")
    }
    
    internal func cleanupDeletionCaches() {
        // Stop all timers
        for (_, timer) in deletionTimers {
            timer.invalidate()
        }
        deletionTimers.removeAll()
        
        // Remove all cached deleted events
        deletedEventsCache.removeAll()
        
        print("Cleaned up all deletion caches")
    }
    
    struct DeletedEventState {
        let eventId: UUID
        let eventType: EventType
        let date: Date
        let dateString: String
        let eventData: Any // Will store either FeedEvent or SleepEvent
        let deletionTime: Date
        
        init(eventId: UUID, eventType: EventType, date: Date, dateString: String, eventData: Any) {
            self.eventId = eventId
            self.eventType = eventType
            self.date = date
            self.dateString = dateString
            self.eventData = eventData
            self.deletionTime = Date() // Current time when deletion occurred
        }
    }
    
    // Structure to store event state for undo/redo functionality
    struct EventState {
        let eventId: UUID
        let eventType: EventType
        let oldStartTime: Date
        let oldEndTime: Date?
        let oldPrepTime: Date?
        
        // Added for redo functionality
        var newStartTime: Date
        var newEndTime: Date?
        var newPrepTime: Date?
        
        // Added to track if this state represents a deletion
        var isDeletion: Bool
        
        // Constructor with just undo data
        init(eventId: UUID, eventType: EventType, oldStartTime: Date, oldEndTime: Date?, oldPrepTime: Date?) {
            self.eventId = eventId
            self.eventType = eventType
            self.oldStartTime = oldStartTime
            self.oldEndTime = oldEndTime
            self.oldPrepTime = oldPrepTime
            self.newStartTime = oldStartTime // Default to the same start time
            self.newEndTime = oldEndTime
            self.newPrepTime = oldPrepTime
            self.isDeletion = false
        }
        
        // Constructor with both undo and redo data
        init(eventId: UUID, eventType: EventType, oldStartTime: Date, oldEndTime: Date?, oldPrepTime: Date?,
             newStartTime: Date, newEndTime: Date?, newPrepTime: Date?, isDeletion: Bool = false) {
            self.eventId = eventId
            self.eventType = eventType
            self.oldStartTime = oldStartTime
            self.oldEndTime = oldEndTime
            self.oldPrepTime = oldPrepTime
            self.newStartTime = newStartTime
            self.newEndTime = newEndTime
            self.newPrepTime = newPrepTime
            self.isDeletion = isDeletion
        }
    }
}
