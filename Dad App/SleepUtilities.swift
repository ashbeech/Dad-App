//
//  SleepUtilities.swift
//  Dad App
//

import Foundation

struct SleepUtilities {
    // Calculate the effective duration of a sleep event, accounting for pauses
    static func calculateEffectiveDuration(sleepEvent: SleepEvent) -> TimeInterval {
        // If not ongoing, simply use the stored end time
        if !sleepEvent.isOngoing {
            return sleepEvent.endTime.timeIntervalSince(sleepEvent.date)
        }
        
        // For ongoing events, calculate up to the current time
        let now = Date()
        let endPoint = sleepEvent.isPaused ? (sleepEvent.lastPauseTime ?? now) : now
        
        // Calculate total pause duration
        var totalPauseDuration: TimeInterval = 0
        for interval in sleepEvent.pauseIntervals {
            totalPauseDuration += interval.resumeTime.timeIntervalSince(interval.pauseTime)
        }
        
        // Calculate total elapsed time minus pauses
        return endPoint.timeIntervalSince(sleepEvent.date) - totalPauseDuration
    }
    
    // Format a duration in hours, minutes and seconds
    static func formatDuration(_ duration: TimeInterval) -> String {
        let hours = Int(duration) / 3600
        let minutes = (Int(duration) % 3600) / 60
        let seconds = Int(duration) % 60
        
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%02d:%02d", minutes, seconds)
        }
    }
    
    // Calculate the effective end time for an ongoing sleep event
    static func calculateEffectiveEndTime(sleepEvent: SleepEvent) -> Date {
        if sleepEvent.isOngoing {
            if sleepEvent.isPaused {
                return sleepEvent.lastPauseTime ?? sleepEvent.endTime
            } else {
                return Date()
            }
        } else {
            return sleepEvent.endTime
        }
    }
    
    // New method: Calculate percentage of sleep completed
    static func calculateCompletionPercentage(sleepEvent: SleepEvent) -> Double {
        if !sleepEvent.isOngoing {
            // For completed events, it's 100%
            return 100.0
        }
        
        // For ongoing events, calculate based on current effective duration vs expected duration
        let effectiveDuration = calculateEffectiveDuration(sleepEvent: sleepEvent)
        
        // Calculate expected duration (from start to scheduled end)
        let expectedDuration = sleepEvent.endTime.timeIntervalSince(sleepEvent.date)
        
        if expectedDuration <= 0 {
            return 100.0 // Avoid division by zero
        }
        
        // Calculate percentage with a cap at 100%
        let percentage = min(100.0, (effectiveDuration / expectedDuration) * 100.0)
        return percentage
    }
    
    // New method: Get time remaining for an ongoing sleep event
    static func calculateTimeRemaining(sleepEvent: SleepEvent) -> TimeInterval {
        if !sleepEvent.isOngoing {
            return 0 // No time remaining for completed events
        }
        
        let effectiveDuration = calculateEffectiveDuration(sleepEvent: sleepEvent)
        let expectedDuration = sleepEvent.endTime.timeIntervalSince(sleepEvent.date)
        
        let remaining = max(0, expectedDuration - effectiveDuration)
        return remaining
    }
    
    // New method: Format time remaining in a human-readable way
    static func formatTimeRemaining(_ timeRemaining: TimeInterval) -> String {
        let minutes = Int(timeRemaining) / 60
        
        if minutes < 1 {
            return "Less than a minute"
        } else if minutes == 1 {
            return "1 minute"
        } else if minutes < 60 {
            return "\(minutes) minutes"
        } else {
            let hours = minutes / 60
            let remainingMinutes = minutes % 60
            
            if remainingMinutes == 0 {
                return "\(hours) \(hours == 1 ? "hour" : "hours")"
            } else {
                return "\(hours) \(hours == 1 ? "hour" : "hours"), \(remainingMinutes) \(remainingMinutes == 1 ? "minute" : "minutes")"
            }
        }
    }
}
