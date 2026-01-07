//
//  ActiveEvent.swift
//  Dad App
//
//  Created by Ash Beech on 08/03/2025.
//

import Foundation

// Model for tracking the currently active (ongoing) event
struct ActiveEvent: Identifiable, Equatable {
    var id: UUID
    var type: EventType
    var startTime: Date
    var isPaused: Bool
    var pauseIntervals: [PauseInterval]
    var lastPauseTime: Date?
    
    init(id: UUID, type: EventType, startTime: Date) {
        self.id = id
        self.type = type
        self.startTime = startTime
        self.isPaused = false
        self.pauseIntervals = []
        self.lastPauseTime = nil
    }
    
    static func from(event: Event) -> ActiveEvent {
        ActiveEvent(id: event.id, type: event.type, startTime: event.date)
    }
    
    static func from(sleepEvent: SleepEvent) -> ActiveEvent {
        var activeEvent = ActiveEvent(id: sleepEvent.id, type: .sleep, startTime: sleepEvent.date)
        activeEvent.isPaused = sleepEvent.isPaused
        activeEvent.pauseIntervals = sleepEvent.pauseIntervals
        activeEvent.lastPauseTime = sleepEvent.lastPauseTime
        return activeEvent
    }
    
    static func from(feedEvent: FeedEvent) -> ActiveEvent {
        ActiveEvent(id: feedEvent.id, type: .feed, startTime: feedEvent.date)
    }
    
    static func == (lhs: ActiveEvent, rhs: ActiveEvent) -> Bool {
        lhs.id == rhs.id
    }
}

// Model for tracking pause intervals in events
struct PauseInterval: Codable, Equatable, Hashable {
    var pauseTime: Date
    var resumeTime: Date
    
    static func == (lhs: PauseInterval, rhs: PauseInterval) -> Bool {
        lhs.pauseTime == rhs.pauseTime && lhs.resumeTime == rhs.resumeTime
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(pauseTime)
        hasher.combine(resumeTime)
    }
}
