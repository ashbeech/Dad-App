//
//  Milestone.swift
//  Dad App
//
//  Represents an intermediate achievement point between goal start and completion.
//  Milestones break large goals into meaningful checkpoints.
//

import Foundation

struct Milestone: Identifiable, Codable {
    var id: UUID
    var goalId: UUID              // Parent goal this belongs to
    var title: String             // e.g., "Validate idea", "Build MVP"
    var targetDate: Date          // When this milestone should be achieved
    var order: Int                // Sequence within the goal (1, 2, 3...)
    var isCompleted: Bool
    var completedDate: Date?      // When it was actually completed
    
    init(id: UUID = UUID(),
         goalId: UUID,
         title: String,
         targetDate: Date,
         order: Int,
         isCompleted: Bool = false,
         completedDate: Date? = nil) {
        self.id = id
        self.goalId = goalId
        self.title = title
        self.targetDate = targetDate
        self.order = order
        self.isCompleted = isCompleted
        self.completedDate = completedDate
    }
}

// MARK: - API Response Types

/// Milestone as returned by the AI API (before we assign UUIDs)
struct GeneratedMilestone: Codable {
    let title: String
    let targetDate: String        // ISO8601 date string from API
    let order: Int
    
    /// Convert to a full Milestone with UUID and parent goal link
    func toMilestone(goalId: UUID) -> Milestone {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate]
        
        let date = formatter.date(from: targetDate) ?? Date()
        
        return Milestone(
            goalId: goalId,
            title: title,
            targetDate: date,
            order: order
        )
    }
}

