//
//  TaskEvent.swift
//  Dad App
//

import SwiftUI
import Foundation

struct TaskEvent: Identifiable, Codable {
    var id: UUID
    var date: Date                    // Actual start time
    var notes: String
    var isTemplate: Bool
    var title: String                 // Original title as entered by user
    var pastTenseTitle: String        // Past tense version for display
    var completed: Bool
    var endTime: Date
    var isOngoing: Bool
    var hasEndTime: Bool              // Whether this task has an end time
    var parentGoalId: UUID?           // Link to parent goal
    var orderInGoal: Int?             // Sequence within the goal
    
    // Phase 1: New scheduling fields
    var milestoneId: UUID?            // Which milestone this belongs to
    var scheduledDate: Date?          // The date AI scheduled this for (may differ from `date`)
    var estimatedMinutes: Int?        // AI's time estimate
    
    init(id: UUID = UUID(),
         date: Date, 
         title: String, 
         endTime: Date, 
         notes: String = "", 
         isTemplate: Bool = false, 
         completed: Bool = false, 
         isOngoing: Bool = false, 
         hasEndTime: Bool = true,
         parentGoalId: UUID? = nil,
         orderInGoal: Int? = nil,
         milestoneId: UUID? = nil,
         scheduledDate: Date? = nil,
         estimatedMinutes: Int? = nil) {
        self.id = id
        self.date = date
        self.notes = notes
        self.isTemplate = isTemplate
        self.title = title
        self.pastTenseTitle = TaskTitleConverter.shared.convertToPastTense(title: title)
        self.completed = completed
        self.endTime = endTime
        self.isOngoing = isOngoing
        self.hasEndTime = hasEndTime
        self.parentGoalId = parentGoalId
        self.orderInGoal = orderInGoal
        self.milestoneId = milestoneId
        self.scheduledDate = scheduledDate
        self.estimatedMinutes = estimatedMinutes
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
    
    /// Whether this task was rescheduled from its original AI-scheduled date
    var wasRescheduled: Bool {
        guard let scheduled = scheduledDate else { return false }
        let calendar = Calendar.current
        return !calendar.isDate(date, inSameDayAs: scheduled)
    }
}
