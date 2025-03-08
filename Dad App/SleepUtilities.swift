//
//  SleepUtilities.swift
//  Dad App
//
//  Created by Ashley Davison on 08/03/2025.
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
        var endPoint = sleepEvent.isPaused ? (sleepEvent.lastPauseTime ?? now) : now
        
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
}
