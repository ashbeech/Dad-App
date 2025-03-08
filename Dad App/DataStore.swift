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
    private let feedEventsKey = "feedEvents"
    private let sleepEventsKey = "sleepEvents"
    
    @Published var baby: Baby
    @Published var events: [String: [Event]] = [:] // [DateString: [Event]]
    @Published var feedEvents: [String: [FeedEvent]] = [:] // [DateString: [FeedEvent]]
    @Published var sleepEvents: [String: [SleepEvent]] = [:] // [DateString: [SleepEvent]]
    
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
    }
    
    func getEvents(for date: Date) -> [Event] {
        let dateString = formatDate(date)
        return events[dateString] ?? []
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
        
        // Calculate total pause duration
        var totalPauseDuration: TimeInterval = 0
        for interval in sleepEvent.pauseIntervals {
            totalPauseDuration += interval.resumeTime.timeIntervalSince(interval.pauseTime)
        }
        
        // If currently paused, add the current pause duration
        if sleepEvent.isPaused, let pauseTime = sleepEvent.lastPauseTime {
            totalPauseDuration += Date().timeIntervalSince(pauseTime)
        }
        
        // Set the end time to now minus the total pause duration
        let now = Date()
        let effectiveEndTime = now.addingTimeInterval(-totalPauseDuration)
        
        // Update the event
        updatedEvent.endTime = effectiveEndTime
        updatedEvent.isOngoing = false
        updatedEvent.isPaused = false
        updatedEvent.lastPauseTime = nil
        
        // Save the updated event
        updateSleepEvent(updatedEvent, for: date)
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
    
    // Undo functionality
    func undoLastChange() {
        guard let lastState = lastEventStates.last else { return }
        
        let calendar = Calendar.current
        let dateComponents = calendar.dateComponents([.year, .month, .day], from: lastState.oldStartTime)
        let date = calendar.date(from: dateComponents) ?? Date()
        
        // Save current state for redo before modifying
        saveCurrentStateForRedo(eventId: lastState.eventId, for: date)
        
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
                    isTemplate: sleepEvent.isTemplate
                )
                
                // Update the sleep event
                updateSleepEvent(restoredEvent, for: date)
                
                // Provide haptic feedback for undo
                let generator = UIImpactFeedbackGenerator(style: .medium)
                generator.impactOccurred()
            }
        case .task: break
            // TODO
        }
        
        // Remove the last event state after using it
        if !lastEventStates.isEmpty {
            lastEventStates.removeLast()
        }
    }
    
    // Redo functionality
    func redoLastChange() {
        guard let redoState = redoEventStates.last else { return }
        
        let calendar = Calendar.current
        let dateComponents = calendar.dateComponents([.year, .month, .day], from: redoState.oldStartTime)
        let date = calendar.date(from: dateComponents) ?? Date()
        
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
                    isTemplate: sleepEvent.isTemplate
                )
                
                // Update the sleep event
                updateSleepEvent(restoredEvent, for: date)
                
                // Provide haptic feedback for redo
                let generator = UIImpactFeedbackGenerator(style: .medium)
                generator.impactOccurred()
            }
        case .task: break
            // TODO
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
        }
    }
    
    func generateDailySchedule(for date: Date) {
        // First check if we already have events for this date
        let dateString = formatDate(date)
        
        var dailyEvents: [Event] = []
        var dailyFeedEvents: [FeedEvent] = []
        var dailySleepEvents: [SleepEvent] = []
        
        // Check if we already have wake and bedtime events
        let existingEvents = events[dateString] ?? []
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
            }
        }
    }
    
    func updateSleepEvent(_ event: SleepEvent, for date: Date) {
        let dateString = formatDate(date)
        
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
                currentSleepEvents[index] = event
                sleepEvents[dateString] = currentSleepEvents
                
                // Update notification
                NotificationManager.shared.cancelNotification(for: event.id)
                NotificationManager.shared.scheduleSleepNotification(for: event)
            }
        }
    }
    
    func deleteFeedEvent(_ event: FeedEvent, for date: Date) {
        let dateString = formatDate(date)
        
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
        }
    }
    
    func deleteSleepEvent(_ event: SleepEvent, for date: Date) {
        let dateString = formatDate(date)
        
        // Delete from events
        if var currentEvents = events[dateString] {
            currentEvents.removeAll(where: { $0.id == event.id })
            events[dateString] = currentEvents
        }
        
        // Delete from sleep events
        if var currentSleepEvents = sleepEvents[dateString] {
            currentSleepEvents.removeAll(where: { $0.id == event.id })
            sleepEvents[dateString] = currentSleepEvents
            
            // Cancel notification
            NotificationManager.shared.cancelNotification(for: event.id)
        }
    }
    
    // Structure to store event state for undo/redo functionality
    struct EventState {
        let eventId: UUID
        let eventType: EventType
        let oldStartTime: Date
        let oldEndTime: Date?
        let oldPrepTime: Date?
        
        // Added for redo functionality - not optional for newStartTime to avoid unwrapping issues
        var newStartTime: Date
        var newEndTime: Date?
        var newPrepTime: Date?
        
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
        }
        
        // Constructor with both undo and redo data
        init(eventId: UUID, eventType: EventType, oldStartTime: Date, oldEndTime: Date?, oldPrepTime: Date?,
             newStartTime: Date, newEndTime: Date?, newPrepTime: Date?) {
            self.eventId = eventId
            self.eventType = eventType
            self.oldStartTime = oldStartTime
            self.oldEndTime = oldEndTime
            self.oldPrepTime = oldPrepTime
            self.newStartTime = newStartTime
            self.newEndTime = newEndTime
            self.newPrepTime = newPrepTime
        }
    }
}
