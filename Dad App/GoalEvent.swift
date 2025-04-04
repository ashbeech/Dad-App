//
//  GoalEvent.swift
//  Dad App
//
//  Created by Ashley Davison on 02/04/2025.
//

import Foundation

struct GoalEvent: Identifiable, Codable {
    var id: UUID
    var date: Date  // This represents the deadline for the goal
    var title: String
    
    init(id: UUID = UUID(), date: Date, title: String) {
        self.id = id
        self.date = date
        self.title = title
    }
    
    func toEvent() -> Event {
        return Event(id: id, type: .goal, date: date, notes: "", isTemplate: false)
    }
    
    static func fromEvent(_ event: Event, title: String = "New Goal") -> GoalEvent {
        return GoalEvent(id: event.id, date: event.date, title: title)
    }
}
