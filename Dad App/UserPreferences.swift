//
//  UserPreferences.swift
//  Dad App
//
//  Stores user's scheduling preferences for AI task generation.
//  These preferences inform how the AI schedules tasks across days.
//

import Foundation

// MARK: - Time Block Enum

enum TimeBlock: String, Codable, CaseIterable {
    case morning = "morning"       // 6am - 12pm
    case afternoon = "afternoon"   // 12pm - 5pm
    case evening = "evening"       // 5pm - 10pm
    
    var displayName: String {
        switch self {
        case .morning: return "Morning"
        case .afternoon: return "Afternoon"
        case .evening: return "Evening"
        }
    }
    
    var typicalStartHour: Int {
        switch self {
        case .morning: return 9
        case .afternoon: return 13
        case .evening: return 18
        }
    }
}

// MARK: - Weekday Enum

enum Weekday: String, Codable, CaseIterable {
    case monday, tuesday, wednesday, thursday, friday, saturday, sunday
    
    var displayName: String {
        rawValue.capitalized
    }
    
    /// Returns weekdays (Mon-Fri)
    static var weekdays: [Weekday] {
        [.monday, .tuesday, .wednesday, .thursday, .friday]
    }
    
    /// Returns all days
    static var allDays: [Weekday] {
        allCases
    }
}

// MARK: - User Preferences

struct UserPreferences: Codable {
    /// Hours available per day for goal tasks (e.g., 2.0)
    var availableHoursPerDay: Double
    
    /// Preferred task duration in minutes (e.g., 30)
    var preferredTaskDurationMinutes: Int
    
    /// Which parts of the day user prefers to work
    var preferredTimeBlocks: [TimeBlock]
    
    /// Which days of the week user works on goals
    var workDays: [Weekday]
    
    init(availableHoursPerDay: Double = 2.0,
         preferredTaskDurationMinutes: Int = 30,
         preferredTimeBlocks: [TimeBlock] = [.morning],
         workDays: [Weekday] = Weekday.weekdays) {
        self.availableHoursPerDay = availableHoursPerDay
        self.preferredTaskDurationMinutes = preferredTaskDurationMinutes
        self.preferredTimeBlocks = preferredTimeBlocks
        self.workDays = workDays
    }
    
    /// Default preferences for new users
    static var `default`: UserPreferences {
        UserPreferences()
    }
    
    /// Convert to dictionary for API request
    func toDictionary() -> [String: Any] {
        return [
            "availableHoursPerDay": availableHoursPerDay,
            "preferredTaskDurationMinutes": preferredTaskDurationMinutes,
            "preferredTimeBlocks": preferredTimeBlocks.map { $0.rawValue },
            "workDays": workDays.map { $0.rawValue }
        ]
    }
}

