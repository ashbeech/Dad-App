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
    var title: String // Original title as entered by user
    var pastTenseTitle: String // Always store a past tense version for display
    var completed: Bool
    var endTime: Date
    var isOngoing: Bool
    var hasEndTime: Bool // Property to track if this task has an end time
    
    init(id: UUID = UUID(), date: Date, title: String, endTime: Date, notes: String = "", isTemplate: Bool = false, completed: Bool = false, isOngoing: Bool = false, hasEndTime: Bool = true) {
        self.id = id
        self.date = date
        self.notes = notes
        self.isTemplate = isTemplate
        self.title = title
        // Always generate past tense title during initialization
        self.pastTenseTitle = TaskTitleConverter.shared.convertToPastTense(title: title)
        self.completed = completed
        self.endTime = endTime
        self.isOngoing = isOngoing
        self.hasEndTime = hasEndTime
    }
    
    // Helper function to get the display title (always past tense)
    func displayTitle() -> String {
        return pastTenseTitle
    }
    
    func toEvent() -> Event {
        return Event(id: id, type: .task, date: date, notes: notes, isTemplate: isTemplate)
    }
    
    static func fromEvent(_ event: Event, title: String = "New Task", endTime: Date? = nil, completed: Bool = false) -> TaskEvent {
        let end = endTime ?? event.date.addingTimeInterval(30 * 60)
        return TaskEvent(id: event.id, date: event.date, title: title, endTime: end, notes: event.notes, isTemplate: event.isTemplate, completed: completed)
    }
}
