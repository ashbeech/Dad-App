//
//  SleepEvent.swift
//  Dad App
//
//  Created by Ashley Davison on 06/03/2025.
//

import Foundation

struct SleepEvent: Identifiable, Codable {
    var id: UUID
    var date: Date
    var notes: String
    var isTemplate: Bool
    var sleepType: SleepType
    var endTime: Date
    var isOngoing: Bool
    var isPaused: Bool
    var pauseIntervals: [PauseInterval]
    var lastPauseTime: Date?
    
    init(id: UUID = UUID(), date: Date, sleepType: SleepType, endTime: Date, notes: String = "", isTemplate: Bool = false, isOngoing: Bool = false, isPaused: Bool = false, pauseIntervals: [PauseInterval] = [], lastPauseTime: Date? = nil) {
        self.id = id
        self.date = date
        self.notes = notes
        self.isTemplate = isTemplate
        self.sleepType = sleepType
        self.endTime = endTime
        self.isOngoing = isOngoing
        self.isPaused = isPaused
        self.pauseIntervals = pauseIntervals
        self.lastPauseTime = lastPauseTime
    }
    
    func toEvent() -> Event {
        return Event(id: id, type: .sleep, date: date, notes: notes, isTemplate: isTemplate)
    }
    
    static func fromEvent(_ event: Event, sleepType: SleepType = .nap, endTime: Date? = nil) -> SleepEvent {
        let end = endTime ?? event.date.addingTimeInterval(30 * 60)
        return SleepEvent(id: event.id, date: event.date, sleepType: sleepType, endTime: end, notes: event.notes, isTemplate: event.isTemplate)
    }
}

