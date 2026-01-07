//
//  NapTimerManager.swift
//  Dad App
//
//  Created by Ash Beech on 10/03/2025.
//

import SwiftUI
import Combine

class NapTimerManager: ObservableObject {
    static let shared = NapTimerManager()
    
    @Published var timerTick: Int = 0
    private var timer: Timer?
    
    private init() {
        // Start a timer that updates every 0.5 seconds
        startTimer()
    }
    
    func startTimer() {
        // Stop any existing timer first
        stopTimer()
        
        // Create a new timer
        timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            self?.timerTick += 1
        }
        
        if let timer = timer {
            RunLoop.main.add(timer, forMode: .common)
        }
    }
    
    func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
    
    // Calculate the effective duration for a sleep event with consistent logic
    func calculateEffectiveDuration(sleepEvent: SleepEvent) -> TimeInterval {
        let now = Date()
        var totalPauseTime: TimeInterval = 0
        
        // Calculate total pause time from completed intervals
        for interval in sleepEvent.pauseIntervals {
            totalPauseTime += interval.resumeTime.timeIntervalSince(interval.pauseTime)
        }
        
        // If currently paused, add the current pause interval
        if sleepEvent.isPaused, let pauseTime = sleepEvent.lastPauseTime {
            totalPauseTime += now.timeIntervalSince(pauseTime)
        }
        
        // Calculate total elapsed time minus pauses
        let effectiveDuration = now.timeIntervalSince(sleepEvent.date) - totalPauseTime
        
        // Print for debugging
        //print("Calculated duration: \(formatDuration(effectiveDuration))")
        //print("- Total elapsed: \(formatDuration(now.timeIntervalSince(sleepEvent.date)))")
        //print("- Total pauses: \(formatDuration(totalPauseTime))")
        
        return effectiveDuration
    }
    
    // Format duration consistently
    func formatDuration(_ duration: TimeInterval) -> String {
        let hours = Int(duration) / 3600
        let minutes = (Int(duration) % 3600) / 60
        let seconds = Int(duration) % 60
        
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%02d:%02d", minutes, seconds)
        }
    }
}
