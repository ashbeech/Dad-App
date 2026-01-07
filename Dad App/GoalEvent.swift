//
//  GoalEvent.swift
//  Dad App
//
//  Created by Ash Beech on 02/04/2025.
//

import Foundation

struct GoalEvent: Identifiable, Codable {
    var id: UUID
    var date: Date              // When created
    var deadline: Date?         // Target completion date
    var title: String
    var taskIds: [UUID]         // IDs of generated tasks
    var milestoneIds: [UUID]    // IDs of milestones (Phase 1)
    var isCompleted: Bool
    
    init(id: UUID = UUID(), 
         date: Date = Date(), 
         deadline: Date? = nil, 
         title: String, 
         taskIds: [UUID] = [],
         milestoneIds: [UUID] = [],
         isCompleted: Bool = false) {
        self.id = id
        self.date = date
        self.deadline = deadline
        self.title = title
        self.taskIds = taskIds
        self.milestoneIds = milestoneIds
        self.isCompleted = isCompleted
    }
    
    func toEvent() -> Event {
        return Event(id: id, type: .goal, date: date, notes: "", isTemplate: false)
    }
    
    static func fromEvent(_ event: Event, title: String = "New Goal") -> GoalEvent {
        return GoalEvent(id: event.id, date: event.date, title: title)
    }
    
    /// Returns true if this goal has AI-generated tasks
    var hasGeneratedTasks: Bool {
        !taskIds.isEmpty
    }
    
    /// Returns true if this goal has milestones
    var hasMilestones: Bool {
        !milestoneIds.isEmpty
    }
}

// MARK: - API Response Types

/// Full response from the task breakdown API
struct TaskBreakdownResponse: Codable {
    let success: Bool
    let goal: String
    let milestones: [GeneratedMilestone]?  // Optional for backward compatibility
    let tasks: [GeneratedTask]
}

/// Task as returned by the AI API (before we create TaskEvents)
struct GeneratedTask: Codable {
    let title: String
    let estimatedMinutes: Int
    let order: Int
    
    // Phase 1: Scheduling fields (optional for backward compatibility)
    let scheduledDate: String?       // ISO8601 date: "2026-01-07"
    let scheduledStartTime: String?  // Time: "09:00"
    let milestoneIndex: Int?         // Which milestone this belongs to (0-indexed)
    
    /// Parse the scheduled date string to a Date
    func getScheduledDate() -> Date? {
        guard let dateString = scheduledDate else { return nil }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate]
        return formatter.date(from: dateString)
    }
    
    /// Parse the scheduled start time and combine with date
    func getScheduledDateTime(fallbackDate: Date) -> Date {
        let calendar = Calendar.current
        let baseDate = getScheduledDate() ?? fallbackDate
        
        guard let timeString = scheduledStartTime else {
            // Default to 9 AM if no time specified
            return calendar.date(bySettingHour: 9, minute: 0, second: 0, of: baseDate) ?? baseDate
        }
        
        // Parse "HH:mm" format
        let components = timeString.split(separator: ":")
        if components.count >= 2,
           let hour = Int(components[0]),
           let minute = Int(components[1]) {
            return calendar.date(bySettingHour: hour, minute: minute, second: 0, of: baseDate) ?? baseDate
        }
        
        return calendar.date(bySettingHour: 9, minute: 0, second: 0, of: baseDate) ?? baseDate
    }
}