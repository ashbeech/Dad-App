//
//  TaskEvent.swift
//  Dad App
//

import SwiftUI
import Foundation

struct TaskEvent: Identifiable, Codable {
    var id: UUID
    var date: Date
    var notes: String
    var isTemplate: Bool
    var title: String
    var completed: Bool
    var priority: TaskPriority
    var endTime: Date
    var isOngoing: Bool
    
    init(id: UUID = UUID(), date: Date, title: String, endTime: Date, notes: String = "", isTemplate: Bool = false, completed: Bool = false, priority: TaskPriority = .medium, isOngoing: Bool = false) {
        self.id = id
        self.date = date
        self.notes = notes
        self.isTemplate = isTemplate
        self.title = title
        self.completed = completed
        self.priority = priority
        self.endTime = endTime
        self.isOngoing = isOngoing
    }
    
    func toEvent() -> Event {
        return Event(id: id, type: .task, date: date, notes: notes, isTemplate: isTemplate)
    }
    
    static func fromEvent(_ event: Event, title: String = "New Task", endTime: Date? = nil, completed: Bool = false, priority: TaskPriority = .medium) -> TaskEvent {
        let end = endTime ?? event.date.addingTimeInterval(30 * 60)
        return TaskEvent(id: event.id, date: event.date, title: title, endTime: end, notes: event.notes, isTemplate: event.isTemplate, completed: completed, priority: priority)
    }
}

enum TaskPriority: String, Codable, CaseIterable {
    case low = "Low"
    case medium = "Medium"
    case high = "High"
    
    var color: Color {
        switch self {
        case .low:
            return .green
        case .medium:
            return .orange
        case .high:
            return .red
        }
    }
}
