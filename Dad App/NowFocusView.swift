//
//  NowFocusView.swift
//  Dad App
//
//  Created by Ashley Davison on 08/03/2025.
//

import SwiftUI

struct NowFocusView: View {
    @EnvironmentObject var dataStore: DataStore
    @Binding var currentActiveEvent: ActiveEvent?
    let date: Date
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Content based on active event
                if let activeEvent = currentActiveEvent {
                    switch activeEvent.type {
                    case .sleep:
                        if let sleepEvent = dataStore.getSleepEvent(id: activeEvent.id, for: date),
                           sleepEvent.sleepType == .nap {
                            NapControlsView(
                                sleepEvent: sleepEvent,
                                date: date,
                                isPaused: activeEvent.isPaused,
                                onPauseTapped: {
                                    togglePauseActiveEvent()
                                },
                                onStopTapped: {
                                    stopActiveEvent()
                                }
                            )
                        }
                    case .feed:
                        // Future implementation for feed events
                        EmptyView()
                    case .task:
                        // Future implementation for task events
                        EmptyView()
                    }
                } else {
                    // Empty state when no active event
                    EmptyView()
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
    }
    
    private func togglePauseActiveEvent() {
        guard var event = currentActiveEvent else { return }
        
        if event.type == .sleep,
           let sleepEvent = dataStore.getSleepEvent(id: event.id, for: date) {
            // Toggle pause state
            if event.isPaused {
                // Resume event
                event.isPaused = false
                event.pauseIntervals.append(PauseInterval(
                    pauseTime: event.lastPauseTime ?? Date(),
                    resumeTime: Date()
                ))
                event.lastPauseTime = nil
            } else {
                // Pause event
                event.isPaused = true
                event.lastPauseTime = Date()
            }
            
            // Update the active event
            currentActiveEvent = event
            
            // Update the sleep event in the data store
            var updatedSleepEvent = sleepEvent
            updatedSleepEvent.pauseIntervals = event.pauseIntervals
            updatedSleepEvent.isOngoing = true
            updatedSleepEvent.isPaused = event.isPaused
            updatedSleepEvent.lastPauseTime = event.lastPauseTime
            
            dataStore.updateSleepEvent(updatedSleepEvent, for: date)
        }
    }
    
    private func stopActiveEvent() {
        guard let event = currentActiveEvent else { return }
        
        if event.type == .sleep,
           let sleepEvent = dataStore.getSleepEvent(id: event.id, for: date) {
            var updatedSleepEvent = sleepEvent
            
            // Calculate total pause duration
            var totalDuration: TimeInterval = 0
            
            // Add up all completed pause intervals
            for interval in event.pauseIntervals {
                totalDuration += interval.resumeTime.timeIntervalSince(interval.pauseTime)
            }
            
            // If currently paused, add the current pause duration
            if event.isPaused, let pauseTime = event.lastPauseTime {
                totalDuration += Date().timeIntervalSince(pauseTime)
            }
            
            // Set the end time to now minus the total pause duration
            let now = Date()
            let effectiveEndTime = now.addingTimeInterval(-totalDuration)
            updatedSleepEvent.endTime = effectiveEndTime
            
            // Save pause intervals for record-keeping
            updatedSleepEvent.pauseIntervals = event.pauseIntervals
            
            // Mark as no longer ongoing
            updatedSleepEvent.isOngoing = false
            updatedSleepEvent.isPaused = false
            updatedSleepEvent.lastPauseTime = nil
            
            dataStore.updateSleepEvent(updatedSleepEvent, for: date)
        }
        
        // Clear the active event
        currentActiveEvent = nil
    }
    
    // Method removed as we now use DataStore methods for calculations
}

struct NapControlsView: View {
    let sleepEvent: SleepEvent
    let date: Date
    let isPaused: Bool
    let onPauseTapped: () -> Void
    let onStopTapped: () -> Void
    
    @State private var elapsedTime: TimeInterval = 0
    @State private var timer: Timer?
    @State private var displayTime: String = "00:00"
    @State private var animateTime: Bool = false
    
    var body: some View {
        VStack {
            Text("Nap")
                .font(.headline)
                .padding(.bottom, 5)
            
            Text(displayTime)
                .font(.system(size: 24, weight: .bold, design: .monospaced))
                .foregroundColor(isPaused ? .orange : .primary)
                .padding(.bottom, 10)
                .scaleEffect(animateTime ? 1.05 : 1.0)
                .animation(animateTime ?
                          Animation.easeInOut(duration: 0.2).repeatCount(1) :
                          .default, value: animateTime)
            
            HStack(spacing: 20) {
                Button(action: onPauseTapped) {
                    ZStack {
                        Circle()
                            .fill(Color.blue.opacity(0.2))
                            .frame(width: 60, height: 60)
                        
                        Image(systemName: isPaused ? "play.fill" : "pause.fill")
                            .font(.title2)
                            .foregroundColor(.blue)
                    }
                }
                
                Button(action: onStopTapped) {
                    ZStack {
                        Circle()
                            .fill(Color.red.opacity(0.2))
                            .frame(width: 60, height: 60)
                        
                        Image(systemName: "stop.fill")
                            .font(.title2)
                            .foregroundColor(.red)
                    }
                }
            }
        }
        /*
        .onAppear {
            // Calculate initial elapsed time
            calculateElapsedTime()
            updateDisplayTime()
            
            // Start a timer to update the elapsed time display (every 0.2 seconds for smoother updates)
            timer = Timer.scheduledTimer(withTimeInterval: 0.2, repeats: true) { _ in
                if !isPaused {
                    let previousSeconds = Int(elapsedTime) % 60
                    calculateElapsedTime()
                    let currentSeconds = Int(elapsedTime) % 60
                    
                    // Animate when seconds change
                    if previousSeconds != currentSeconds {
                        animateTimeChange()
                    }
                    
                    updateDisplayTime()
                }
            }
        }*/
        .onAppear {
            // Calculate initial elapsed time
            calculateElapsedTime()
            
            // Start a more frequent timer to update the elapsed time display (every 0.2 seconds for smoother updates)
            timer = Timer.scheduledTimer(withTimeInterval: 0.2, repeats: true) { _ in
                if !isPaused {
                    calculateElapsedTime()
                }
            }
        }
        .onDisappear {
            timer?.invalidate()
            timer = nil
        }
    }
    
    private func calculateElapsedTime() {
        let now = Date()
        var totalPauseTime: TimeInterval = 0
        
        // Calculate total pause time
        for interval in sleepEvent.pauseIntervals {
            totalPauseTime += interval.resumeTime.timeIntervalSince(interval.pauseTime)
        }
        
        // If currently paused, add the current pause duration
        if isPaused, let pauseTime = sleepEvent.lastPauseTime {
            totalPauseTime += now.timeIntervalSince(pauseTime)
        }
        
        // Calculate elapsed time (now - startTime - totalPauseTime)
        elapsedTime = now.timeIntervalSince(sleepEvent.date) - totalPauseTime
    }
    
    private func updateDisplayTime() {
        displayTime = formattedElapsedTime()
    }
    
    private func animateTimeChange() {
        withAnimation {
            animateTime = true
        }
        
        // Reset animation after a delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            withAnimation {
                animateTime = false
            }
        }
    }
    
    private func formattedElapsedTime() -> String {
        let hours = Int(elapsedTime) / 3600
        let minutes = (Int(elapsedTime) % 3600) / 60
        let seconds = Int(elapsedTime) % 60
        
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%02d:%02d", minutes, seconds)
        }
    }
}
