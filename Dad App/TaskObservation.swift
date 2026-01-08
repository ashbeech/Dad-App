//
//  TaskObservation.swift
//  Dad App
//
//  Phase 3: Behavioral learning - tracks what happens to tasks
//

import Foundation

// MARK: - Observation Event Types

enum ObservationEventType: String, Codable {
    case completed      // Task was marked complete
    case rescheduled    // Task was moved to a different date/time
    case edited         // Task title or duration was changed
    case skipped        // Task was explicitly skipped/dismissed
    case started        // Task was started (for duration tracking)
}

// MARK: - Task Observation

/// Records a single event that happened to a task
struct TaskObservation: Identifiable, Codable {
    let id: UUID
    let taskId: UUID
    let goalId: UUID?
    let milestoneId: UUID?
    let timestamp: Date
    let eventType: ObservationEventType
    
    // Context at time of observation
    let dayOfWeek: Int              // 1 = Sunday, 7 = Saturday
    let hourOfDay: Int              // 0-23
    let timeBlock: TimeBlock?       // morning/afternoon/evening
    
    // For .completed events
    let scheduledDate: Date?
    let scheduledStartTime: Date?
    let actualCompletionTime: Date?
    let estimatedMinutes: Int?
    let actualMinutes: Int?         // nil if not tracked
    let wasOnTime: Bool?            // completed on scheduled day?
    
    // For .edited events
    let previousTitle: String?
    let newTitle: String?
    let previousDuration: Int?
    let newDuration: Int?
    
    // For .rescheduled events
    let previousDate: Date?
    let newDate: Date?
    let rescheduleReason: String?   // optional user input
    
    init(
        id: UUID = UUID(),
        taskId: UUID,
        goalId: UUID? = nil,
        milestoneId: UUID? = nil,
        timestamp: Date = Date(),
        eventType: ObservationEventType,
        scheduledDate: Date? = nil,
        scheduledStartTime: Date? = nil,
        actualCompletionTime: Date? = nil,
        estimatedMinutes: Int? = nil,
        actualMinutes: Int? = nil,
        wasOnTime: Bool? = nil,
        previousTitle: String? = nil,
        newTitle: String? = nil,
        previousDuration: Int? = nil,
        newDuration: Int? = nil,
        previousDate: Date? = nil,
        newDate: Date? = nil,
        rescheduleReason: String? = nil
    ) {
        self.id = id
        self.taskId = taskId
        self.goalId = goalId
        self.milestoneId = milestoneId
        self.timestamp = timestamp
        self.eventType = eventType
        
        // Calculate time context
        let calendar = Calendar.current
        self.dayOfWeek = calendar.component(.weekday, from: timestamp)
        self.hourOfDay = calendar.component(.hour, from: timestamp)
        self.timeBlock = TaskObservation.determineTimeBlock(hour: self.hourOfDay)
        
        self.scheduledDate = scheduledDate
        self.scheduledStartTime = scheduledStartTime
        self.actualCompletionTime = actualCompletionTime
        self.estimatedMinutes = estimatedMinutes
        self.actualMinutes = actualMinutes
        self.wasOnTime = wasOnTime
        self.previousTitle = previousTitle
        self.newTitle = newTitle
        self.previousDuration = previousDuration
        self.newDuration = newDuration
        self.previousDate = previousDate
        self.newDate = newDate
        self.rescheduleReason = rescheduleReason
    }
    
    // MARK: - Helpers
    
    private static func determineTimeBlock(hour: Int) -> TimeBlock {
        switch hour {
        case 5..<12: return .morning
        case 12..<17: return .afternoon
        default: return .evening
        }
    }
    
    /// Age of this observation in days
    var ageInDays: Int {
        let calendar = Calendar.current
        let now = Date()
        return calendar.dateComponents([.day], from: timestamp, to: now).day ?? 0
    }
    
    /// Weight for this observation (recent = higher weight)
    /// Uses exponential decay: weight = e^(-age/halfLife)
    /// halfLife of 30 means observations lose half their weight every 30 days
    func weight(halfLifeDays: Double = 30) -> Double {
        let age = Double(ageInDays)
        let decayConstant = log(2) / halfLifeDays
        return exp(-decayConstant * age)
    }
}

// MARK: - Factory Methods

extension TaskObservation {
    
    /// Create a completion observation
    static func completed(
        task: TaskEvent,
        actualMinutes: Int? = nil
    ) -> TaskObservation {
        let calendar = Calendar.current
        let wasOnTime = task.scheduledDate.map { calendar.isDateInToday($0) } ?? true
        
        return TaskObservation(
            taskId: task.id,
            goalId: task.parentGoalId,
            milestoneId: task.milestoneId,
            eventType: .completed,
            scheduledDate: task.scheduledDate,
            scheduledStartTime: task.date,
            actualCompletionTime: Date(),
            estimatedMinutes: task.estimatedMinutes,
            actualMinutes: actualMinutes,
            wasOnTime: wasOnTime
        )
    }
    
    /// Create an edit observation
    static func edited(
        task: TaskEvent,
        previousTitle: String,
        previousDuration: Int?
    ) -> TaskObservation {
        return TaskObservation(
            taskId: task.id,
            goalId: task.parentGoalId,
            milestoneId: task.milestoneId,
            eventType: .edited,
            previousTitle: previousTitle,
            newTitle: task.title,
            previousDuration: previousDuration,
            newDuration: task.estimatedMinutes
        )
    }
    
    /// Create a reschedule observation
    static func rescheduled(
        task: TaskEvent,
        previousDate: Date,
        reason: String? = nil
    ) -> TaskObservation {
        return TaskObservation(
            taskId: task.id,
            goalId: task.parentGoalId,
            milestoneId: task.milestoneId,
            eventType: .rescheduled,
            previousDate: previousDate,
            newDate: task.scheduledDate ?? task.date,
            rescheduleReason: reason
        )
    }
    
    /// Create a skip observation
    static func skipped(task: TaskEvent) -> TaskObservation {
        return TaskObservation(
            taskId: task.id,
            goalId: task.parentGoalId,
            milestoneId: task.milestoneId,
            eventType: .skipped,
            scheduledDate: task.scheduledDate,
            scheduledStartTime: task.date,
            estimatedMinutes: task.estimatedMinutes
        )
    }
}


