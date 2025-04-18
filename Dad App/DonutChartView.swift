//
//  DonutChartView.swift
//  Dad App
//
//  Created by Ashley Davison on 06/03/2025.
//

import SwiftUI
import UIKit

struct DonutChartView: View {
    @EnvironmentObject var dataStore: DataStore
    let date: Date
    let events: [Event]
    var onAddEventTapped: (Date) -> Void
    var onDateChanged: (Date) -> Void // New callback for date changes
    
    @Binding var selectedEvent: Event?
    @Binding var filteredEventTypes: [EventType]?
    
    @State private var dragState = DragState()
    @State private var currentActiveEvent: ActiveEvent? = nil
    @State private var timer: Timer? = nil
    @State private var pauseStateObserver: NSObjectProtocol? = nil
    @State private var refreshTrigger: Bool = false
    @State private var lastWakeTime: Date = Date()
    @State private var lastBedTime: Date = Date()
    @State private var currentTimeAngle: Double = 0
    @State private var animateCurrentTimeLine: Bool = false
    @State private var timerUpdateCounter: Int = 0
    @State private var forceRedraw: UUID = UUID()
    @State private var lastActiveNapId: UUID? = nil
    @State private var showLockAnimation: Bool = false
    
    private struct DragState {
        var isDragging: Bool = false
        var draggedEventId: UUID? = nil
        var dragTime: Date = Date()
        var dragAngle: Double = 0
        var showConfirmationTime: Bool = false
        var dragMode: DragMode = .wholeSleep
        var dragEndTime: Date = Date()
        var dragEndAngle: Double = 0
        var originalStartTime: Date = Date()
        var originalEndTime: Date = Date()
        var dragStartLocation: CGPoint = .zero
        var dragStartAngleOffset: Double = 0 // Add this to track angle offset
        static var lastKnownPositions: [UUID: (startAngle: Double, endAngle: Double?)] = [:]
        
        mutating func reset() {
            isDragging = false
            draggedEventId = nil
            showConfirmationTime = false
            dragStartAngleOffset = 0
        }
    }
    
    // Enum to track what part of sleep event is being dragged
    private enum DragMode {
        case startPoint
        case endPoint
        case wholeSleep
    }
    
    // New state variables for the carousel effect
    @State private var dragOffset: CGFloat = 0
    @State private var isDraggingHorizontally: Bool = false
    @State private var previousDate: Date = Date()
    @State private var nextDate: Date = Date()
    
    // The swipe threshold to trigger a day change (percentage of width)
    private let swipeThreshold: CGFloat = 0.3
    // Use full screen width instead of geometry width for proper spacing
    let fullScreenWidth = UIScreen.main.bounds.width
    
    init(date: Date, events: [Event], selectedEvent: Binding<Event?>, filteredEventTypes: Binding<[EventType]?>,
         onAddEventTapped: @escaping (Date) -> Void, onDateChanged: @escaping (Date) -> Void) {
        self.date = date
        self.events = events
        self._selectedEvent = selectedEvent
        self._filteredEventTypes = filteredEventTypes
        self.onAddEventTapped = onAddEventTapped
        self.onDateChanged = onDateChanged
        
        // Calculate previous and next dates
        let calendar = Calendar.current
        self._previousDate = State(initialValue: calendar.date(byAdding: .day, value: -1, to: date) ?? date)
        self._nextDate = State(initialValue: calendar.date(byAdding: .day, value: 1, to: date) ?? date)
    }
    
    var body: some View {
        GeometryReader { geometry in
            // The carousel container with horizontal drag gesture
            ZStack {
                
                // Previous day's arc (positioned one full screen width to the left)
                createPreviousDayArc(geometry: geometry)
                    .offset(x: -fullScreenWidth + dragOffset)
                    // Always show adjacent days with slight transparency while dragging
                    .opacity(isDraggingHorizontally ? 1.0 : 0)
                
                // Current day's arc (center position)
                createMainArc(geometry: geometry)
                    .offset(x: dragOffset)
                
                // Next day's arc (positioned one full screen width to the right)
                createNextDayArc(geometry: geometry)
                    .offset(x: fullScreenWidth + dragOffset)
                    // Always show adjacent days with slight transparency while dragging
                    .opacity(isDraggingHorizontally ? 1.0 : 0)
            }
            .gesture(
                DragGesture()
                    .onChanged { value in
                        // Only handle horizontal drag if we're not already dragging an event
                        if !dragState.isDragging {
                            let horizontalDrag = abs(value.translation.width) > abs(value.translation.height)
                            
                            if horizontalDrag {
                                isDraggingHorizontally = true
                                dragOffset = value.translation.width
                            }
                        }
                    }
                    .onEnded { value in
                        if isDraggingHorizontally {
                            let fullScreenWidth = UIScreen.main.bounds.width
                            let threshold = fullScreenWidth * swipeThreshold
                            
                            if dragOffset > threshold {
                                // Swiped right past threshold - go to previous day
                                // First, animate the rest of the movement to fully show the previous day
                                withAnimation(.easeInOut(duration: 0.3)) {
                                    dragOffset = fullScreenWidth // Move completely to the right
                                }
                                
                                // Then, after the animation completes, update the actual date
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                    // Change the date without animation
                                    onDateChanged(previousDate)
                                    
                                    // Reset drag offset without animation
                                    dragOffset = 0
                                    isDraggingHorizontally = false
                                }
                                
                            } else if dragOffset < -threshold {
                                // Swiped left past threshold - go to next day
                                // First, animate the rest of the movement to fully show the next day
                                withAnimation(.easeInOut(duration: 0.3)) {
                                    dragOffset = -fullScreenWidth // Move completely to the left
                                }
                                
                                // Then, after the animation completes, update the actual date
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                    // Change the date without animation
                                    onDateChanged(nextDate)
                                    
                                    // Reset drag offset without animation
                                    dragOffset = 0
                                    isDraggingHorizontally = false
                                }
                                
                            } else {
                                // Not past threshold - animate back to center
                                withAnimation(.easeInOut(duration: 0.3)) {
                                    dragOffset = 0
                                }
                                
                                // Reset drag state after animation completes
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                    isDraggingHorizontally = false
                                }
                            }
                        }
                    }
            )
            .onChange(of: date) { _, newDate in
                // Update previous and next dates when the current date changes
                let calendar = Calendar.current
                previousDate = calendar.date(byAdding: .day, value: -1, to: newDate) ?? newDate
                nextDate = calendar.date(byAdding: .day, value: 1, to: newDate) ?? newDate
            }
        }
        .aspectRatio(1, contentMode: .fit)
        .padding()
    }
    
    // Helper function to create the main arc view
    private func createMainArc(geometry: GeometryProxy) -> some View {
        ZStack {
            // Draw the arc representing wake hours
            PreciseArcStroke(
                startAngle: arcStartAngle,
                endAngle: arcEndAngle,
                clockwise: true,
                lineWidth: donutWidth,
                color: Color.gray.opacity(0.7),
                onDoubleTap: { angle in
                    guard dataStore.isEditingAllowed(for: date) else { return }
                    // Only proceed if not already dragging something
                    if !dragState.isDragging && !isDraggingHorizontally {
                        
                        if !dataStore.isEditingAllowed(for: date) {
                            // Show lock feedback
                            showLockFeedback()
                            return
                        }
                        
                        // Convert angle to time
                        let tappedTime = timeFromAngle(angle)
                        
                        // Call the callback with the tapped time
                        onAddEventTapped(tappedTime)
                        
                        // Provide haptic feedback
                        let generator = UIImpactFeedbackGenerator(style: .medium)
                        generator.impactOccurred()
                    }
                },
                date: date
            )
            .environmentObject(dataStore)
            .frame(width: geometry.size.width + donutWidth, height: geometry.size.height + donutWidth)
            .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
            
            // Render wake and bedtime circles (fixed positions)
            specialEventsView(geometry: geometry)
                .zIndex(5) // Fixed position events
            
            // Render all events in sorted z-index order
            ForEach(prepareEventRenderOrder()) { renderData in
                renderEvent(renderData.event, geometry: geometry)
                    .zIndex(renderData.zIndex)
            }
            
            // Draw the current time marker if within waking hours AND it's today
            currentTimeMarkerView(geometry: geometry)
                .zIndex(666)
            
            // Time markers for better readability
            timeMarkersView(geometry: geometry)
                .zIndex(2) // Just above base arc
            
            // CRITICAL: Always render the NowFocusView in the center
            NowFocusView(currentActiveEvent: $currentActiveEvent, date: date)
                .frame(width: geometry.size.width * 0.6, height: geometry.size.height * 0.6)
                .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
                .zIndex(300) // Highest z-index - always on top
                .environmentObject(dataStore)
            
            // Time label during drag
            dragTimeLabelsView(geometry: geometry)
                .zIndex(333)
            
            // Confirmation time label after drop
            confirmationTimeLabelsView(geometry: geometry)
                .zIndex(333)
        }
        .overlay(
            LockFeedbackOverlay(isVisible: $showLockAnimation)
        )
        .id(forceRedraw)
    }
    
    // Helper function to create the previous day's arc
    private func createPreviousDayArc(geometry: GeometryProxy) -> some View {
        let previousDayEvents = dataStore.getEvents(for: previousDate)
        
        return ZStack {
            // Base arc for previous day
            PreciseArcStroke(
                startAngle: arcStartAngle,
                endAngle: arcEndAngle,
                clockwise: true,
                lineWidth: donutWidth,
                color: Color.gray.opacity(0.5), // Slightly more transparent
                onDoubleTap: { _ in /* Disabled for side arcs */ },
                date: previousDate
            )
            .environmentObject(dataStore)
            .frame(width: geometry.size.width + donutWidth, height: geometry.size.height + donutWidth)
            .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
            
            // Simple representation of previous day's events - reduced complexity
            Text(Calendar.current.isDateInToday(previousDate) ? "Today" : formatDayOfWeek(previousDate))
                .font(.headline)
                .foregroundColor(.gray)
                .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
        }
    }
    
    // Helper function to create the next day's arc
    private func createNextDayArc(geometry: GeometryProxy) -> some View {
        let nextDayEvents = dataStore.getEvents(for: nextDate)
        
        return ZStack {
            // Base arc for next day
            PreciseArcStroke(
                startAngle: arcStartAngle,
                endAngle: arcEndAngle,
                clockwise: true,
                lineWidth: donutWidth,
                color: Color.gray.opacity(0.5), // Slightly more transparent
                onDoubleTap: { _ in /* Disabled for side arcs */ },
                date: nextDate
            )
            .environmentObject(dataStore)
            .frame(width: geometry.size.width + donutWidth, height: geometry.size.height + donutWidth)
            .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
            
            // Simple representation of next day's events - reduced complexity
            Text(Calendar.current.isDateInToday(nextDate) ? "Today" : formatDayOfWeek(nextDate))
                .font(.headline)
                .foregroundColor(.gray)
                .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
        }
    }
    
    // Helper to format day of week
    private func formatDayOfWeek(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE" // Full day name
        return formatter.string(from: date)
    }
    
    private func renderEvent(_ event: Event, geometry: GeometryProxy) -> some View {
        Group {
            switch event.type {
            case .feed:
                feedEventView(event: event, geometry: geometry)
            case .sleep:
                if let _ = getSleepEventForDate(event) {
                    sleepEventView(event: event, geometry: geometry)
                }
            case .task:
                if let _ = getTaskEventForDate(event) {
                    taskEventView(event: event, geometry: geometry)
                }
            case .goal:
                if let _ = getTaskEventForDate(event) {
                    taskEventView(event: event, geometry: geometry)
                }
            }
        }
    }
    
    private let donutWidth: CGFloat = 50
    private let arcStartAngle: Double = 110
    private let arcEndAngle: Double = 70
    
    private struct EventRenderData: Identifiable {
        let id: UUID
        let event: Event
        let eventType: EventType
        let isBeingDragged: Bool
        let duration: TimeInterval
        let isOngoing: Bool
        let isPaused: Bool
        
        // Calculate z-index based on all factors
        var zIndex: Double {
            // Base z-index starting point
            var zIndex: Double = 10
            
            // First priority: dragged elements always on top
            if isBeingDragged {
                return 100 // Highest priority
            }
            
            // Second priority: event type and state
            switch eventType {
            case .feed:
                zIndex = 50 // Feed events (circles) high priority
            case .task:
                zIndex = 40 // Task events (potentially capsules) medium-high priority
            case .sleep:
                // Special handling for sleep events
                if isOngoing {
                    zIndex = 70 // Ongoing naps get higher priority
                    if isPaused {
                        zIndex = 65 // Paused ongoing naps slightly lower
                    }
                } else {
                    zIndex = 30 // Normal sleep events low priority
                }
            case .goal: break
            }
            
            // Third priority: adjust by duration (smaller events higher in stack)
            // Invert the relationship - longer duration = lower z-index
            if duration > 0 {
                // Calculate a scaling factor based on duration
                // Maximum reduction of 20 points for events longer than 2 hours (7200 seconds)
                let maxReduction: Double = 20
                let maxDuration: Double = 7200 // 2 hours in seconds
                
                // Clamp duration between 0 and maxDuration
                let clampedDuration = min(duration, maxDuration)
                
                // Calculate reduction - longer events get bigger reductions in z-index
                let reduction = (clampedDuration / maxDuration) * maxReduction
                
                // Apply reduction to z-index
                zIndex -= reduction
            }
            
            return zIndex
        }
    }
    
    private func prepareEventRenderOrder() -> [EventRenderData] {
        var renderData: [EventRenderData] = []
        
        // Process all events
        for event in events {
            let isBeingDragged = dragState.draggedEventId == event.id
            var duration: TimeInterval = 0
            var isOngoing = false
            var isPaused = false
            
            // Extract specific properties based on event type
            switch event.type {
            case .sleep:
                if let sleepEvent = getSleepEventForDate(event) {
                    duration = sleepEvent.endTime.timeIntervalSince(sleepEvent.date)
                    isOngoing = sleepEvent.isOngoing && sleepEvent.sleepType == .nap && Calendar.current.isDateInToday(date)
                    isPaused = sleepEvent.isPaused
                    
                    // Skip wake and bedtime events as they have fixed positions
                    if sleepEvent.sleepType == .waketime || sleepEvent.sleepType == .bedtime {
                        continue
                    }
                }
            case .task:
                if let taskEvent = getTaskEventForDate(event) {
                    duration = taskEvent.endTime.timeIntervalSince(taskEvent.date)
                }
            case .feed:
                // Feed events are points, so 0 duration
                duration = 0
            case .goal: break
            }
            
            // Create render data entry
            let renderEntry = EventRenderData(
                id: event.id,
                event: event,
                eventType: event.type,
                isBeingDragged: isBeingDragged,
                duration: duration,
                isOngoing: isOngoing,
                isPaused: isPaused
            )
            
            renderData.append(renderEntry)
        }
        
        // Sort by z-index (low to high so higher z-index renders on top)
        return renderData.sorted { $0.zIndex < $1.zIndex }
    }
    
    // Get z-index for a specific event
    func getZIndex(for event: Event) -> Double {
        let isBeingDragged = dragState.draggedEventId == event.id
        var duration: TimeInterval = 0
        var isOngoing = false
        var isPaused = false
        
        // Get event-specific properties
        switch event.type {
        case .sleep:
            if let sleepEvent = getSleepEventForDate(event) {
                duration = sleepEvent.endTime.timeIntervalSince(sleepEvent.date)
                isOngoing = sleepEvent.isOngoing && sleepEvent.sleepType == .nap && Calendar.current.isDateInToday(date)
                isPaused = sleepEvent.isPaused
                
                // Special handling for wake/bedtime
                if sleepEvent.sleepType == .waketime || sleepEvent.sleepType == .bedtime {
                    return 5 // Fixed low priority
                }
            }
        case .task:
            if let taskEvent = getTaskEventForDate(event) {
                duration = taskEvent.endTime.timeIntervalSince(taskEvent.date)
            }
        case .feed:
            duration = 0
        case .goal: break
        }
        
        // Create render data and get z-index
        let renderEntry = EventRenderData(
            id: event.id,
            event: event,
            eventType: event.type,
            isBeingDragged: isBeingDragged,
            duration: duration,
            isOngoing: isOngoing,
            isPaused: isPaused
        )
        
        return renderEntry.zIndex
    }
    
    // MARK: - Component Views
    
    private func taskEventView(event: Event, geometry: GeometryProxy) -> some View {
        Group {
            if let taskEvent = getTaskEventForDate(event) {
                let isEventInvolved = dragState.draggedEventId == event.id
                
                if taskEvent.hasEndTime {
                    // For tasks with duration (has end time), show capsule
                    
                    // Calculate display times based on drag state
                    let displayStartTime: Date = {
                        if isEventInvolved {
                            switch dragState.dragMode {
                            case .startPoint:
                                return dragState.dragTime
                            case .endPoint:
                                return taskEvent.date
                            case .wholeSleep: // Reusing the same enum for tasks
                                return dragState.dragTime
                            }
                        } else {
                            return taskEvent.date
                        }
                    }()
                    
                    let displayEndTime: Date = {
                        if isEventInvolved {
                            switch dragState.dragMode {
                            case .startPoint:
                                return taskEvent.endTime
                            case .endPoint:
                                return dragState.dragEndTime
                            case .wholeSleep: // Reusing the same enum for tasks
                                return dragState.dragEndTime
                            }
                        } else {
                            return taskEvent.endTime
                        }
                    }()
                    
                    // Now create the actual view elements
                    Group {
                        // The main capsule body
                        ZStack {
                            TaskArcCapsule(
                                startAngle: angleForTime(displayStartTime),
                                endAngle: angleForTime(displayEndTime),
                                donutWidth: donutWidth * 0.8,
                                color: .green,
                                isCompleted: taskEvent.completed
                            )
                            .shadow(radius: isEventInvolved ? 4 : 0)
                            
                            // Add task title in the middle of the arc
                            let middleAngle = (angleForTime(displayStartTime) + angleForTime(displayEndTime)) / 2
                            Text(taskEvent.title.prefix(4))
                                .font(.system(size: 10))
                                .foregroundColor(.white)
                                .fontWeight(.bold)
                                .position(pointOnDonutCenter(angle: middleAngle, geometry: geometry))
                        }
                        
                        // Start circle
                        Circle()
                            .fill(Color.green)
                            .frame(width: donutWidth * 0.8, height: donutWidth * 0.8)
                            .position(pointOnDonutCenter(angle: angleForTime(displayStartTime), geometry: geometry))
                        
                        // End circle
                        Circle()
                            .fill(Color.green)
                            .frame(width: donutWidth * 0.8, height: donutWidth * 0.8)
                            .position(pointOnDonutCenter(angle: angleForTime(displayEndTime), geometry: geometry))
                    }
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                guard dataStore.isEditingAllowed(for: date) else { return }
                                // Disable animations during drag for better performance
                                var transaction = Transaction()
                                transaction.disablesAnimations = true
                                withTransaction(transaction) {
                                    handleTaskEventDragChange(value: value, event: event, taskEvent: taskEvent, geometry: geometry)
                                }
                            }
                            .onEnded { value in
                                handleTaskEventDragEnd(value: value, event: event)
                            }
                    )
                    .onTapGesture {
                        guard dataStore.isEditingAllowed(for: date) else { return }
                        if !dragState.isDragging && (Calendar.current.isDateInToday(date) || dataStore.isPastDateEditingEnabled) {
                            selectedEvent = event
                        }
                    }
                } else {
                    // For tasks without duration (reminder style), just show a circle like feed events
                    let displayTime: Date = {
                        if isEventInvolved {
                            return dragState.dragTime
                        } else {
                            return taskEvent.date
                        }
                    }()
                    
                    // Create a simple circle like feed events
                    Circle()
                        .fill(Color.green)
                        .frame(width: donutWidth * 0.8, height: donutWidth * 0.8)
                        .scaleEffect(dragState.isDragging && isEventInvolved ? 1.2 : 1.0)
                        .shadow(radius: dragState.isDragging && isEventInvolved ? 4 : 0)
                        .position(pointOnDonutCenter(angle: angleForTime(displayTime), geometry: geometry))
                        .gesture(
                            DragGesture()
                                .onChanged { value in
                                    guard dataStore.isEditingAllowed(for: date) else { return }
                                    var transaction = Transaction()
                                    transaction.disablesAnimations = true
                                    withTransaction(transaction) {
                                        // Handle drag as point event (like feed events)
                                        handleReminderTaskDragChange(value: value, event: event, geometry: geometry)
                                    }
                                }
                                .onEnded { value in
                                    handleReminderTaskDragEnd(value: value, event: event)
                                }
                        )
                        .onTapGesture {
                            guard dataStore.isEditingAllowed(for: date) else { return }
                            if !dragState.isDragging {
                                selectedEvent = event
                            }
                        }
                }
            }
        }
    }
    
    private func sleepEventView(event: Event, geometry: GeometryProxy) -> some View {
        Group {
            if let sleepEvent = getSleepEventForDate(event) {
                let isEventInvolved = dragState.draggedEventId == event.id
                let isOngoing = sleepEvent.isOngoing && sleepEvent.sleepType == .nap && Calendar.current.isDateInToday(date)
                let isPaused = sleepEvent.isPaused
                
                // Calculate display times based on drag state and ongoing status
                let displayStartTime: Date = {
                    if isEventInvolved && !isOngoing {
                        switch dragState.dragMode {
                        case .startPoint:
                            return dragState.dragTime
                        case .endPoint:
                            return sleepEvent.date
                        case .wholeSleep:
                            return dragState.dragTime
                        }
                    } else {
                        return sleepEvent.date
                    }
                }()
                
                let displayEndTime: Date = {
                    if isEventInvolved && !isOngoing {
                        switch dragState.dragMode {
                        case .startPoint:
                            return sleepEvent.endTime
                        case .endPoint:
                            return dragState.dragEndTime
                        case .wholeSleep:
                            return dragState.dragEndTime
                        }
                    } else if isOngoing {
                        if isPaused, let pauseTime = sleepEvent.lastPauseTime {
                            // For paused naps, use the pause time as the end point
                            return pauseTime
                        } else {
                            // For ongoing naps that aren't paused, use the current time as the end
                            return Date()
                        }
                    } else {
                        return sleepEvent.endTime
                    }
                }()
                
                // Now create the actual view elements
                Group {
                    // The main capsule body
                    ZStack {
                        SleepArcCapsule(
                            startAngle: angleForTime(displayStartTime),
                            endAngle: angleForTime(displayEndTime),
                            donutWidth: donutWidth * 0.8,
                            color: colorForEvent(event),
                            isOngoing: isOngoing,
                            isPaused: isPaused
                        )
                        .shadow(radius: isEventInvolved ? 4 : 0)
                        
                        // Add a status indicator for ongoing naps in the middle of the arc
                        /*
                         if isOngoing {
                         let middleAngle = (angleForTime(displayStartTime) + angleForTime(displayEndTime)) / 2
                         
                         Image(systemName: isPaused ? "pause.fill" : "lock.fill")
                         .font(.system(size: 12))
                         .foregroundColor(.white)
                         .position(pointOnDonutCenter(angle: middleAngle, geometry: geometry))
                         
                         }
                         */
                    }
                    
                    // Start circle
                    Circle()
                        .fill(colorForEvent(event))
                        .frame(width: donutWidth * 0.8, height: donutWidth * 0.8)
                        .position(pointOnDonutCenter(angle: angleForTime(displayStartTime), geometry: geometry))
                    
                    // End circle with different styling for ongoing vs. completed naps
                    if isOngoing {
                        PulsingCircle(
                            color: colorForEvent(event),
                            size: donutWidth * 0.8,
                            isPaused: isPaused
                        )
                        .position(pointOnDonutCenter(angle: angleForTime(displayEndTime), geometry: geometry))
                    } else {
                        Circle()
                            .fill(colorForEvent(event))
                            .frame(width: donutWidth * 0.8, height: donutWidth * 0.8)
                            .position(pointOnDonutCenter(angle: angleForTime(displayEndTime), geometry: geometry))
                    }
                }
                // Only apply drag gesture for non-ongoing naps
                .gesture(
                    isOngoing ? nil : // No gesture for ongoing naps
                    DragGesture()
                        .onChanged { value in
                            guard dataStore.isEditingAllowed(for: date) else { return }
                            if !isOngoing {
                                var transaction = Transaction()
                                transaction.disablesAnimations = true
                                withTransaction(transaction) {
                                    handleSleepEventDragChange(value: value, event: event, sleepEvent: sleepEvent, geometry: geometry)
                                }
                            }
                        }
                        .onEnded { value in
                            if !isOngoing {
                                handleSleepEventDragEnd(value: value, event: event)
                            }
                        }
                )
                // For non-ongoing naps, allow selection. For ongoing, defer to NowFocusView
                .onTapGesture {
                    guard dataStore.isEditingAllowed(for: date) else { return }
                    
                    // CRITICAL FIX: Don't allow editing of ongoing naps
                    if !dragState.isDragging {
                        // Check if this is an ongoing nap
                        if isOngoing && Calendar.current.isDateInToday(date) {
                            // For ongoing naps, instead of editing, make sure it's the active nap
                            if currentActiveEvent == nil || currentActiveEvent?.id != sleepEvent.id {
                                currentActiveEvent = ActiveEvent.from(sleepEvent: sleepEvent)
                                forceRedraw = UUID()
                                refreshTrigger.toggle()
                            }
                        } else {
                            // Only select non-ongoing naps for editing
                            selectedEvent = event
                        }
                    }
                }
                // Add a dedicated ID to force updates when pause state changes
                .id("sleep-event-\(event.id)-\(isPaused ? "paused" : "running")-\(refreshTrigger)")
                .onAppear {
                    
                    // Remove any existing observer first to avoid duplicates
                    if let observer = pauseStateObserver {
                        NotificationCenter.default.removeObserver(observer)
                    }
                    
                    // Listen for notifications about pause state changes
                    pauseStateObserver = NotificationCenter.default.addObserver(
                        forName: NSNotification.Name("NapPauseStateChanged"),
                        object: nil,
                        queue: .main
                    ) { notification in
                        if let eventId = notification.object as? UUID, eventId == event.id {
                            // Disable animations for state updates from notifications
                            var transaction = Transaction()
                            transaction.disablesAnimations = true
                            withTransaction(transaction) {
                                refreshTrigger.toggle()
                            }
                        }
                    }
                }
                .onDisappear {
                    if let observer = pauseStateObserver {
                        NotificationCenter.default.removeObserver(observer)
                        pauseStateObserver = nil
                    }                }
            }
        }
    }
    
    private func handleReminderTaskDragChange(value: DragGesture.Value, event: Event, geometry: GeometryProxy) {
        // This is similar to handleFeedEventDragChange but specifically for reminder tasks
        guard dataStore.isEditingAllowed(for: date) else { return }
        
        if !dragState.isDragging, let _ = dataStore.getTaskEvent(id: event.id, for: date) {
            dataStore.saveCurrentStateForUndo(eventId: event.id, for: date)
            let generator = UIImpactFeedbackGenerator(style: .light)
            generator.impactOccurred()
        }
        
        // Calculate new angle directly from drag position
        let newAngle = angleFromPoint(value.location, geometry: geometry)
        let constrainedAngle = constrainAngleToArc(newAngle)
        let newTime = timeFromAngle(constrainedAngle)
        
        // Update UI state
        withAnimation(nil) {
            dragState.isDragging = true
            dragState.draggedEventId = event.id
            dragState.dragMode = .wholeSleep // Default mode for point events
            dragState.dragAngle = constrainedAngle
            dragState.dragTime = newTime
            dragState.showConfirmationTime = false
        }
    }
    
    private func handleReminderTaskDragEnd(value: DragGesture.Value, event: Event) {
        guard dataStore.isEditingAllowed(for: date) else { return }
        
        // This is similar to updateEventTime but specifically for reminder tasks
        if let taskEvent = getTaskEventForDate(event) {
            // Calculate updated end time (1 minute after start time for point events)
            let updatedEndTime = dragState.dragTime.addingTimeInterval(60)
            
            // Create updated task event
            let updatedTaskEvent = TaskEvent(
                id: taskEvent.id,
                date: dragState.dragTime,
                title: taskEvent.title,
                endTime: updatedEndTime,
                notes: taskEvent.notes,
                isTemplate: taskEvent.isTemplate,
                completed: taskEvent.completed,
                isOngoing: false,
                hasEndTime: false // Maintain the reminder-style (no end time)
            )
            
            // Update the task event
            dataStore.updateTaskEvent(updatedTaskEvent, for: date)
            
            // Store the final position for future dragging
            DragState.lastKnownPositions[event.id] = (startAngle: dragState.dragAngle, endAngle: nil)
        }
        
        // Show confirmation with the same time
        withAnimation(.easeOut(duration: 0.2)) {
            dragState.isDragging = false
            dragState.showConfirmationTime = true
        }
        
        // Keep dragState.draggedEventId until confirmation is hidden
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            withAnimation(.easeOut(duration: 0.2)) {
                dragState.showConfirmationTime = false
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                if dragState.draggedEventId == event.id {
                    dragState.reset()
                }
            }
        }
    }
    
    private func enhancedTimerSetup() {
        // Cancel any existing timer first to avoid duplicate timers
        timer?.invalidate()
        timer = nil
        
        // Reset the current time angle immediately for today's date
        if Calendar.current.isDateInToday(date) {
            if let currentTime = getCurrentTimeForToday() {
                // Use transaction to avoid animation on initial setup
                var transaction = Transaction()
                transaction.disablesAnimations = true
                withTransaction(transaction) {
                    currentTimeAngle = angleForTime(currentTime)
                    // Force UI update
                    refreshTrigger.toggle()
                }
            }
            
            // Check for ongoing naps only once at startup
            checkForOngoingNaps()
        }
        
        // Create a timer with more reasonable timing - every 60 seconds instead of 15
        timer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { _ in
            if Calendar.current.isDateInToday(self.date) {
                if let currentTime = self.getCurrentTimeForToday() {
                    // Calculate new angle
                    let newAngle = self.angleForTime(currentTime)
                    
                    // Only update if the angle has changed significantly (> 0.5 degrees)
                    if abs(newAngle - self.currentTimeAngle) > 0.5 {
                        // Allow animation for smooth transitions
                        self.currentTimeAngle = newAngle
                        // Force UI update with toggle
                        self.refreshTrigger.toggle()
                    }
                }
            }
            
            self.timerUpdateCounter += 1
            
            // Only check for ongoing naps every 5 timer ticks (2.5 minutes) instead of every tick
            if self.timerUpdateCounter % 5 == 0 {
                self.checkForOngoingNaps()
            }
        }
        
        // Ensure timer runs even when scrolling
        if let timer = timer {
            RunLoop.main.add(timer, forMode: .common)
        }
    }
    
    private func validateSleepEventTimes(startTime: Date, endTime: Date) -> (Date, Date) {
        let calendar = Calendar.current
        
        // Get wake and bedtime for constraints
        let wakeEvent = findWakeEvent()
        let bedtimeEvent = findBedtimeEvent()
        let wakeTime = wakeEvent?.date ?? dataStore.baby.wakeTime
        let bedTime = bedtimeEvent?.date ?? dataStore.baby.bedTime
        
        // Track original date components to preserve them in final result
        let startDateComponents = calendar.dateComponents([.year, .month, .day], from: startTime)
        let endDateComponents = calendar.dateComponents([.year, .month, .day], from: endTime)
        
        // Convert all times to minute components within the day for easier comparison
        let wakeComponents = calendar.dateComponents([.hour, .minute], from: wakeTime)
        let bedComponents = calendar.dateComponents([.hour, .minute], from: bedTime)
        let startComponents = calendar.dateComponents([.hour, .minute], from: startTime)
        let endComponents = calendar.dateComponents([.hour, .minute], from: endTime)
        
        // Convert to minutes since midnight
        let wakeMinutes = (wakeComponents.hour ?? 0) * 60 + (wakeComponents.minute ?? 0)
        let bedMinutes = (bedComponents.hour ?? 0) * 60 + (bedComponents.minute ?? 0)
        let startMinutes = (startComponents.hour ?? 0) * 60 + (startComponents.minute ?? 0)
        let endMinutes = (endComponents.hour ?? 0) * 60 + (endComponents.minute ?? 0)
        
        // Debug log for time validation
        //print("Validating times - Wake: \(wakeMinutes/60):\(wakeMinutes%60), Bed: \(bedMinutes/60):\(bedMinutes%60)")
        //print("Start: \(startMinutes/60):\(startMinutes%60), End: \(endMinutes/60):\(endMinutes%60)")
        
        // Check if bedtime is after midnight
        let isBedtimeAfterMidnight = bedMinutes < wakeMinutes
        
        //print("Total waking minutes: \(totalWakingMinutes), isBedtimeAfterMidnight: \(isBedtimeAfterMidnight)")
        
        // Initialize validated times with input times
        var validStartMinutes = startMinutes
        var validEndMinutes = endMinutes
        
        // Special handling for dragging nap end points
        // If we're dragging the end point of a nap and the drag is close to bedtime,
        // don't snap immediately to bedtime, allow smoother transitions
        let isNearBedtime = abs(endMinutes - bedMinutes) < 10 // Within 10 minutes
        
        // Normal validation logic with improved boundary handling
        
        // 1. First handle the start time validation
        if isBedtimeAfterMidnight {
            // For overnight bedtimes, check if start time is in valid range
            if !(startMinutes >= wakeMinutes || startMinutes <= bedMinutes) {
                // Start time is outside valid range, clamp to nearest valid time
                if abs(startMinutes - wakeMinutes) < abs(startMinutes - (bedMinutes + 24 * 60)) {
                    validStartMinutes = wakeMinutes // Closer to wake time
                } else {
                    validStartMinutes = bedMinutes // Closer to bed time
                }
            }
        } else {
            // For same-day bedtimes, start time must be between wake and bed time
            if startMinutes < wakeMinutes {
                validStartMinutes = wakeMinutes
            } else if startMinutes > bedMinutes {
                validStartMinutes = bedMinutes
            }
        }
        
        // 2. Then handle end time validation
        if isBedtimeAfterMidnight {
            // For overnight bedtimes, check if end time is in valid range
            if !(endMinutes >= wakeMinutes || endMinutes <= bedMinutes) {
                // End time is outside valid range, clamp to nearest valid time
                if abs(endMinutes - wakeMinutes) < abs(endMinutes - (bedMinutes + 24 * 60)) {
                    validEndMinutes = wakeMinutes // Closer to wake time
                } else {
                    validEndMinutes = bedMinutes // Closer to bed time
                }
            }
        } else {
            // For same-day bedtimes, end time must be between wake and bed time
            if endMinutes < wakeMinutes {
                validEndMinutes = wakeMinutes
            } else if endMinutes > bedMinutes && !isNearBedtime {
                validEndMinutes = bedMinutes
            }
        }
        
        // 3. Ensure end time is after start time (with minimum duration of 15 minutes)
        let minDurationMinutes = 15
        
        // Compare times considering day wrap for overnight bedtimes
        let timesOnSameDay = (validStartMinutes <= validEndMinutes && !isBedtimeAfterMidnight) ||
        (validStartMinutes > validEndMinutes && isBedtimeAfterMidnight)
        
        if !timesOnSameDay || validEndMinutes - validStartMinutes < minDurationMinutes {
            // Ensure minimum duration by adjusting end time
            validEndMinutes = validStartMinutes + minDurationMinutes
            
            // If adjusted end time exceeds bed time, cap to bed time
            if !isBedtimeAfterMidnight && validEndMinutes > bedMinutes {
                // If we can't fit the minimum duration, adjust start time instead
                if bedMinutes - wakeMinutes < minDurationMinutes {
                    validStartMinutes = bedMinutes - minDurationMinutes
                } else {
                    validEndMinutes = bedMinutes
                }
            } else if isBedtimeAfterMidnight && validEndMinutes > bedMinutes && validEndMinutes < wakeMinutes {
                // For overnight bedtime, handle edge case
                validEndMinutes = bedMinutes
            }
        }
        
        // 4. Ensure duration is not more than 12 hours
        let maxDurationMinutes = 12 * 60 // 12 hours in minutes
        
        let durationMinutes: Int
        if isBedtimeAfterMidnight && ((validStartMinutes >= wakeMinutes && validEndMinutes <= bedMinutes) ||
                                      (validStartMinutes <= bedMinutes && validEndMinutes >= wakeMinutes)) {
            // Special case for overnight events
            if validStartMinutes >= wakeMinutes && validEndMinutes <= bedMinutes {
                // Both times on next day
                durationMinutes = validEndMinutes - validStartMinutes
            } else if validStartMinutes <= bedMinutes && validEndMinutes >= wakeMinutes {
                // Event spans overnight
                durationMinutes = (24 * 60 - validStartMinutes) + validEndMinutes
            } else {
                // Shouldn't happen, but provide fallback
                durationMinutes = validEndMinutes - validStartMinutes
            }
        } else {
            // Standard case
            durationMinutes = validEndMinutes - validStartMinutes
        }
        
        if durationMinutes > maxDurationMinutes {
            // If over 12 hours, cap to 12 hours from start
            validEndMinutes = validStartMinutes + maxDurationMinutes
            
            // Handle day wrap for long durations
            if !isBedtimeAfterMidnight && validEndMinutes >= 24 * 60 {
                validEndMinutes %= (24 * 60)
            } else if isBedtimeAfterMidnight && validEndMinutes > bedMinutes && validEndMinutes < wakeMinutes {
                validEndMinutes = bedMinutes
            }
        }
        
        // Convert back to dates with the correct date components
        var finalStartComponents = startDateComponents
        finalStartComponents.hour = validStartMinutes / 60
        finalStartComponents.minute = validStartMinutes % 60
        
        var finalEndComponents = endDateComponents
        finalEndComponents.hour = validEndMinutes / 60
        finalEndComponents.minute = validEndMinutes % 60
        
        // Handle day adjustment for overnight scenarios
        if validEndMinutes < validStartMinutes && !isBedtimeAfterMidnight {
            // Standard overnight case
            finalEndComponents.day = (finalEndComponents.day ?? 0) + 1
        } else if isBedtimeAfterMidnight {
            // Special handling for custom bedtime periods
            if validStartMinutes >= wakeMinutes && validEndMinutes < wakeMinutes {
                // Start today, end tomorrow
                finalEndComponents.day = (finalEndComponents.day ?? 0) + 1
            } else if validStartMinutes < wakeMinutes && validEndMinutes >= wakeMinutes {
                // Start tomorrow, end tomorrow
                finalStartComponents.day = (finalStartComponents.day ?? 0) + 1
                finalEndComponents.day = (finalEndComponents.day ?? 0) + 1
            }
        }
        
        let validStartTime = calendar.date(from: finalStartComponents) ?? startTime
        let validEndTime = calendar.date(from: finalEndComponents) ?? endTime
        
        return (validStartTime, validEndTime)
    }
    
    private func feedEventsView(geometry: GeometryProxy) -> some View {
        ForEach(events.filter { event in
            // Only include feed events that match the filter if active
            event.type == .feed && (filteredEventTypes?.contains(.feed) ?? true || filteredEventTypes == nil)
        }) { event in
            feedEventView(event: event, geometry: geometry)
                .id("feed-\(event.id)-\(refreshTrigger)") // Force refresh when trigger changes
        }
    }
    
    private func feedEventView(event: Event, geometry: GeometryProxy) -> some View {
        // Determine if this event is being dragged or was just dragged
        let isEventInvolved = dragState.draggedEventId == event.id
        
        // Choose which time/angle to use for positioning
        let displayTime = (isEventInvolved) ? dragState.dragTime : event.date
        let angle = angleForTime(displayTime)
        
        // Draw the event circle
        return Circle()
            .fill(colorForEvent(event))
            .frame(width: donutWidth * 0.8, height: donutWidth * 0.8)
            .scaleEffect(dragState.isDragging && isEventInvolved ? 1.2 : 1.0)
            .shadow(radius: dragState.isDragging && isEventInvolved ? 4 : 0)
            .position(pointOnDonutCenter(angle: angle, geometry: geometry))
            .gesture(
                DragGesture()
                    .onChanged { value in
                        guard dataStore.isEditingAllowed(for: date) else { return }
                        if !dragState.isDragging, let _ = dataStore.getFeedEvent(id: event.id, for: date) {
                            dataStore.saveCurrentStateForUndo(eventId: event.id, for: date)
                            let generator = UIImpactFeedbackGenerator(style: .light)
                            generator.impactOccurred()
                        }
                        
                        // Disable animations during drag for better performance
                        var transaction = Transaction()
                        transaction.disablesAnimations = true
                        withTransaction(transaction) {
                            handleFeedEventDragChange(value: value, event: event, geometry: geometry)
                        }
                    }
                    .onEnded { value in
                        handleFeedEventDragEnd(value: value, event: event)
                    }
            )
            .onTapGesture {
                guard dataStore.isEditingAllowed(for: date) else { return }
                if !dragState.isDragging {
                    selectedEvent = event
                }
            }
    }
    
    private func taskEventsView(geometry: GeometryProxy) -> some View {
        ForEach(events.filter { event in
            // Only include task events that match the filter if active
            event.type == .task && (filteredEventTypes?.contains(.task) ?? true || filteredEventTypes == nil)
        }) { event in
            taskEventView(event: event, geometry: geometry)
                .id("task-\(event.id)-\(refreshTrigger)") // Force refresh when trigger changes
        }
    }
    
    private func specialEventsView(geometry: GeometryProxy) -> some View {
        Group {
            // Draw wake time circle (orange) at the start of the arc
            let wakeEvent = findWakeEvent()
            
            // Always show wake event regardless of filter
            Circle()
                .fill(Color.orange)
                .frame(width: donutWidth, height: donutWidth)
                .position(pointOnDonutCenter(angle: arcStartAngle, geometry: geometry))
                .onTapGesture {
                    guard dataStore.isEditingAllowed(for: date) else { return }
                    if !dragState.isDragging {
                        // Check if editing is allowed
                        if dataStore.isEditingAllowed(for: date) {
                            if let event = wakeEvent {
                                selectedEvent = event.toEvent()
                            } else {
                                createDefaultWakeEvent()
                            }
                        } else {
                            showLockFeedback()
                        }
                    }
                }
            
            // Draw bed time circle (blue) at the end of the arc
            let bedtimeEvent = findBedtimeEvent()
            
            // Always show bedtime event regardless of filter
            Circle()
                .fill(Color.blue)
                .frame(width: donutWidth, height: donutWidth)
                .position(pointOnDonutCenter(angle: arcEndAngle, geometry: geometry))
                .onTapGesture {
                    guard dataStore.isEditingAllowed(for: date) else { return }
                    if !dragState.isDragging {
                        // Check if editing is allowed
                        if dataStore.isEditingAllowed(for: date) {
                            if let event = bedtimeEvent {
                                selectedEvent = event.toEvent()
                            } else {
                                createDefaultBedtimeEvent()
                            }
                        } else {
                            showLockFeedback()
                        }
                    }
                }
        }
        .id("specialEvents-\(refreshTrigger)")
    }
    
    private func refreshCurrentTimeMarkerView() {
        if Calendar.current.isDateInToday(date), let currentTime = getCurrentTimeForToday()  {
            currentTimeAngle = angleForTime(currentTime)
        }
        refreshTrigger.toggle()
    }
    
    internal func currentTimeMarkerView(geometry: GeometryProxy) -> some View {
        Group {
            if Calendar.current.isDateInToday(date) && !isAfterBedtime() {
                
                let angleRadians = currentTimeAngle * .pi / 180
                let center = CGPoint(x: geometry.size.width / 2, y: geometry.size.height / 2)
                let radius = min(geometry.size.width, geometry.size.height) / 2
                let innerRadius = radius - donutWidth * 0.8
                let outerRadius = radius + donutWidth * 0.8
                
                let innerPoint = CGPoint(
                    x: center.x + innerRadius * cos(angleRadians),
                    y: center.y + innerRadius * sin(angleRadians)
                )
                
                let outerPoint = CGPoint(
                    x: center.x + outerRadius * cos(angleRadians),
                    y: center.y + outerRadius * sin(angleRadians)
                )
                
                Path { path in
                    path.move(to: innerPoint)
                    path.addLine(to: outerPoint)
                }
                .stroke(Color.red, lineWidth: 3)
                .shadow(color: Color.red.opacity(0.4), radius: 2, x: 0, y: 0)
            }
        }
        .onAppear {
            
            // Listen for direct notifications about event changes
            NotificationCenter.default.addObserver(
                forName: NSNotification.Name("EventDataChanged"),
                object: nil,
                queue: .main
            ) { _ in
                refreshCurrentTimeMarkerView()
            }
            
            NotificationCenter.default.addObserver(
                forName: UIApplication.didBecomeActiveNotification,
                object: nil,
                queue: .main
            ) { _ in
                refreshCurrentTimeMarkerView()
            }
            
        }.onDisappear() {
            NotificationCenter.default.removeObserver(self)
        }
        .id("timeMarker-\(forceRedraw)")
    }
    
    private func isAfterBedtime() -> Bool {
        let now = Date()
        
        // Find the actual bedtime event if it exists, otherwise use the default from baby settings
        let bedtimeEvent = dataStore.findBedtimeEvent(for: date)
        let bedTime = bedtimeEvent?.date ?? dataStore.baby.bedTime
        
        // Get current time components
        let calendar = Calendar.current
        let nowComponents = calendar.dateComponents([.hour, .minute], from: now)
        
        // Get bedtime components
        let bedComponents = calendar.dateComponents([.hour, .minute], from: bedTime)
        
        // Convert both to minutes since midnight for comparison
        let nowMinutes = (nowComponents.hour ?? 0) * 60 + (nowComponents.minute ?? 0)
        let bedMinutes = (bedComponents.hour ?? 0) * 60 + (bedComponents.minute ?? 0)
        
        // For bedtimes after midnight, adjust comparison
        if bedMinutes < 360 { // Assuming bedtime won't be before 6am
            // If now is after midnight but before bedtime, it's not after bedtime
            if nowMinutes < 360 && nowMinutes < bedMinutes {
                return false
            }
            
            // If now is after 6pm, it's after bedtime
            return nowMinutes >= 1080 // 6pm = 18 * 60 = 1080
        }
        
        return nowMinutes >= bedMinutes
    }
    
    private func timeMarkersView(geometry: GeometryProxy) -> some View {
        // Get fresh values directly from dataStore each time this is called
        // DO NOT use cached values like lastWakeTime/lastBedTime
        let wakeEvent = findWakeEvent()
        let bedtimeEvent = findBedtimeEvent()
        let wakeTime = wakeEvent?.date ?? dataStore.baby.wakeTime
        let bedTime = bedtimeEvent?.date ?? dataStore.baby.bedTime
        
        // Print for debugging
        print("Generating time markers: Wake=\(wakeTime), Bed=\(bedTime)")
        
        let calendar = Calendar.current
        let wakeComponents = calendar.dateComponents([.hour, .minute], from: wakeTime)
        let bedComponents = calendar.dateComponents([.hour, .minute], from: bedTime)
        
        guard let wakeHour = wakeComponents.hour, let wakeMinute = wakeComponents.minute,
              let bedHour = bedComponents.hour, let bedMinute = bedComponents.minute else {
            print("Failed to extract hour/minute components")
            return AnyView(EmptyView())
        }
        
        let wakeTimeHour = Double(wakeHour) + (Double(wakeMinute) / 60.0)
        var bedTimeHour = Double(bedHour) + (Double(bedMinute) / 60.0)
        
        // Adjust for overnight bedtime
        if bedTimeHour < wakeTimeHour {
            bedTimeHour += 24.0
        }
        
        let totalWakingHours = round(100 * (bedTimeHour - wakeTimeHour)) / 100
        print("Total waking hours: \(totalWakingHours)")
        
        // Generate appropriate time markers based on waking hours
        let markers = generateTimeMarkers(wakeHour: wakeTimeHour, totalWakingHours: totalWakingHours)
        //print("Generated markers: \(markers)")
        
        return AnyView(
            Group {
                ForEach(markers, id: \.self) { hourValue in
                    // Create a date for this hour
                    if let hourDate = createDateForHour(hourValue) {
                        let angle = angleForTime(hourDate)
                        
                        Text(formatHourLabel(hourValue))
                            .font(.caption)
                            .foregroundColor(.gray)
                            .position(pointOutsideDonut(angle: angle, geometry: geometry, offset: 20))
                    }
                }
            }
                .id("timeMarkers-\(refreshTrigger)")
        )
    }
    
    private func generateTimeMarkers(wakeHour: Double, totalWakingHours: Double) -> [Double] {
        var markers = [Double]()
        
        // Determine marker spacing based on total hours
        let spacing: Double
        if totalWakingHours <= 8 {
            spacing = 1.0 // Every hour
        } else if totalWakingHours <= 14 {
            spacing = 2.0 // Every 2 hours
        } else if totalWakingHours <= 20 {
            spacing = 3.0 // Every 3 hours
        } else {
            spacing = 4.0 // Every 4 hours
        }
        
        // Generate markers at appropriate intervals
        var currentHour = ceil(wakeHour / spacing) * spacing // Round up to next spacing increment
        let endHour = wakeHour + totalWakingHours
        
        // Handle case where we might need to wrap around midnight
        if endHour > 24 {
            // First add all markers up to midnight
            while currentHour < 24 {
                markers.append(currentHour)
                currentHour += spacing
            }
            
            // Reset to 0 hour and continue adding markers
            currentHour = spacing * ceil(0 / spacing)
            let remainingHours = endHour.truncatingRemainder(dividingBy: 24)
            while currentHour < remainingHours {
                markers.append(currentHour)
                currentHour += spacing
            }
        } else {
            // No wraparound needed
            while currentHour < endHour {
                markers.append(currentHour)
                currentHour += spacing
            }
        }
        
        return markers
    }
    
    // Helper to create a Date for a given hour value (can include fractional hours)
    private func createDateForHour(_ hourValue: Double) -> Date? {
        let calendar = Calendar.current
        var dateComponents = calendar.dateComponents([.year, .month, .day], from: date)
        
        let wholeHours = Int(hourValue) % 24
        let minutes = Int((hourValue - Double(wholeHours)) * 60)
        
        dateComponents.hour = wholeHours
        dateComponents.minute = minutes
        
        return calendar.date(from: dateComponents)
    }
    
    // Helper to format hour label (converts 24h to 12h format with AM/PM)
    private func formatHourLabel(_ hourValue: Double) -> String {
        let wholeHours = Int(hourValue) % 24
        
        // Format as 12-hour with AM/PM
        let hour12 = wholeHours == 0 ? 12 : (wholeHours > 12 ? wholeHours - 12 : wholeHours)
        let ampm = wholeHours >= 12 ? "PM" : "AM"
        
        return "\(hour12)\(ampm)"
    }
    
    private func dragTimeLabelsView(geometry: GeometryProxy) -> some View {
        Group {
            if dragState.isDragging, dragState.draggedEventId != nil {
                Group {
                    switch dragState.dragMode {
                    case .startPoint:
                        Text(formatTime(dragState.dragTime))
                            .font(.caption)
                            .foregroundColor(.white)
                            .padding(6)
                            .background(Color.black.opacity(0.7))
                            .cornerRadius(8)
                            // Reduced offset by 20px to bring labels closer to the arc
                            .position(pointOutsideDonut(angle: dragState.dragAngle, geometry: geometry, offset: 20))

                    case .endPoint:
                        Text(formatTime(dragState.dragEndTime))
                            .font(.caption)
                            .foregroundColor(.white)
                            .padding(6)
                            .background(Color.black.opacity(0.7))
                            .cornerRadius(8)
                            // Reduced offset by 20px to bring labels closer to the arc
                            .position(pointOutsideDonut(angle: dragState.dragEndAngle, geometry: geometry, offset: 20))

                    case .wholeSleep:
                        if let event = events.first(where: { $0.id == dragState.draggedEventId }) {
                            if event.type == .task,
                               let taskEvent = getTaskEventForDate(event),
                               !taskEvent.hasEndTime {
                                // For reminder-style tasks without end time, just show a single time
                                Text(formatTime(dragState.dragTime))
                                    .font(.caption)
                                    .foregroundColor(.white)
                                    .padding(6)
                                    .background(Color.black.opacity(0.7))
                                    .cornerRadius(8)
                                    // Reduced offset by 20px
                                    .position(pointOutsideDonut(angle: dragState.dragAngle, geometry: geometry, offset: 20))
                            } else if event.type == .sleep ||
                                        (event.type == .task &&
                                        (getTaskEventForDate(event)?.hasEndTime ?? false)) {
                                // Show both start and end times for capsule-style events
                                VStack(spacing: 2) {
                                    Text(formatTime(dragState.dragTime))
                                    Text("-")
                                    Text(formatTime(dragState.dragEndTime))
                                }
                                .font(.caption)
                                .foregroundColor(.white)
                                .padding(6)
                                .background(Color.black.opacity(0.7))
                                .cornerRadius(8)
                                .position(pointOutsideDonut(angle: (dragState.dragAngle + dragState.dragEndAngle) / 2, geometry: geometry, offset: 20))
                            } else {
                                // For point events like feed, show just one time
                                Text(formatTime(dragState.dragTime))
                                    .font(.caption)
                                    .foregroundColor(.white)
                                    .padding(6)
                                    .background(Color.black.opacity(0.7))
                                    .cornerRadius(8)
                                    // Reduced offset by 20px
                                    .position(pointOutsideDonut(angle: dragState.dragAngle, geometry: geometry, offset: 20))
                            }
                        } else {
                            // Fallback if event not found
                            Text(formatTime(dragState.dragTime))
                                .font(.caption)
                                .foregroundColor(.white)
                                .padding(6)
                                .background(Color.black.opacity(0.7))
                                .cornerRadius(8)
                                // Reduced offset by 20px
                                .position(pointOutsideDonut(angle: dragState.dragAngle, geometry: geometry, offset: 20))
                        }
                    }
                }
            }
        }
    }
    
    private func confirmationTimeLabelsView(geometry: GeometryProxy) -> some View {
        Group {
            if dragState.showConfirmationTime, !dragState.isDragging, dragState.draggedEventId != nil {
                Group {
                    // Use the exact same switch statement logic as dragTimeLabelsView
                    switch dragState.dragMode {
                    case .startPoint:
                        Text(formatTime(dragState.dragTime))
                            .font(.caption)
                            .foregroundColor(.white)
                            .padding(6)
                            .background(Color.green.opacity(0.9)) // Only change the color from black to green
                            .cornerRadius(8)
                        // Reduced offset by 20px to match dragTimeLabelsView
                            .position(pointOutsideDonut(angle: dragState.dragAngle, geometry: geometry, offset: 20))
                            .transition(.opacity)
                        
                    case .endPoint:
                        Text(formatTime(dragState.dragEndTime))
                            .font(.caption)
                            .foregroundColor(.white)
                            .padding(6)
                            .background(Color.green.opacity(0.9))
                            .cornerRadius(8)
                        // Reduced offset by 20px to match dragTimeLabelsView
                            .position(pointOutsideDonut(angle: dragState.dragEndAngle, geometry: geometry, offset: 20))
                            .transition(.opacity)
                        
                    case .wholeSleep:
                        if let event = events.first(where: { $0.id == dragState.draggedEventId }) {
                            if event.type == .task,
                               let taskEvent = getTaskEventForDate(event),
                               !taskEvent.hasEndTime {
                                // For reminder-style tasks without end time, just show a single time
                                Text(formatTime(dragState.dragTime))
                                    .font(.caption)
                                    .foregroundColor(.white)
                                    .padding(6)
                                    .background(Color.green.opacity(0.9))
                                    .cornerRadius(8)
                                // Reduced offset by 20px to match dragTimeLabelsView
                                    .position(pointOutsideDonut(angle: dragState.dragAngle, geometry: geometry, offset: 20))
                                    .transition(.opacity)
                            } else if event.type == .sleep ||
                                        (event.type == .task &&
                                         (getTaskEventForDate(event)?.hasEndTime ?? false)) {
                                // Show both start and end times for capsule-style events
                                VStack(spacing: 2) {
                                    Text(formatTime(dragState.dragTime))
                                    Text("-")
                                    Text(formatTime(dragState.dragEndTime))
                                }
                                .font(.caption)
                                .foregroundColor(.white)
                                .padding(6)
                                .background(Color.green.opacity(0.9))
                                .cornerRadius(8)
                                .position(pointOutsideDonut(angle: (dragState.dragAngle + dragState.dragEndAngle) / 2, geometry: geometry, offset: 20))
                                .transition(.opacity)
                            } else {
                                // For point events like feed, show just one time
                                Text(formatTime(dragState.dragTime))
                                    .font(.caption)
                                    .foregroundColor(.white)
                                    .padding(6)
                                    .background(Color.green.opacity(0.9))
                                    .cornerRadius(8)
                                    .position(pointOutsideDonut(angle: dragState.dragAngle, geometry: geometry, offset: 20))
                                    .transition(.opacity)
                            }
                        } else {
                            // Fallback if event not found
                            Text(formatTime(dragState.dragTime))
                                .font(.caption)
                                .foregroundColor(.white)
                                .padding(6)
                                .background(Color.green.opacity(0.9))
                                .cornerRadius(8)
                                .position(pointOutsideDonut(angle: dragState.dragAngle, geometry: geometry, offset: 20))
                                .transition(.opacity)
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Drag Handling
    
    private func handleSleepEventDragChange(value: DragGesture.Value, event: Event, sleepEvent: SleepEvent, geometry: GeometryProxy) {
        guard dataStore.isEditingAllowed(for: date) else { return }
        
        // Check if this is an ongoing nap - if so, abort immediately
        let isOngoing = sleepEvent.isOngoing && sleepEvent.sleepType == .nap && Calendar.current.isDateInToday(date)
        if isOngoing {
            // Don't allow any dragging of ongoing naps
            return
        }
        
        // First drag begins - determine drag mode and store initial values
        if !dragState.isDragging {
            // Store original times for whole sleep dragging
            dragState.originalStartTime = sleepEvent.date
            dragState.originalEndTime = sleepEvent.endTime
            
            // Store the initial touch location
            dragState.dragStartLocation = value.startLocation
            
            // Get the last known position if available
            if let lastPosition = DragState.lastKnownPositions[event.id] {
                // Calculate angles
                let startAngle = lastPosition.startAngle
                let endAngle = lastPosition.endAngle ?? angleForTime(sleepEvent.endTime)
                let tapAngle = angleFromPoint(value.startLocation, geometry: geometry)
                
                // Calculate distance from tap to start and end points
                let startDiff = angleDifference(tapAngle, startAngle)
                let endDiff = angleDifference(tapAngle, endAngle)
                
                // Determine drag mode based on proximity to start/end points
                if startDiff < 10 { // Within 10 degrees of start
                    dragState.dragMode = .startPoint
                    dragState.dragAngle = startAngle
                    dragState.dragTime = timeFromAngle(startAngle)
                } else if endDiff < 10 { // Within 10 degrees of end
                    dragState.dragMode = .endPoint
                    dragState.dragEndAngle = endAngle
                    dragState.dragEndTime = timeFromAngle(endAngle)
                } else {
                    // Dragging the whole sleep event - store both endpoints
                    dragState.dragMode = .wholeSleep
                    dragState.dragAngle = startAngle
                    dragState.dragTime = timeFromAngle(startAngle)
                    dragState.dragEndAngle = endAngle
                    dragState.dragEndTime = timeFromAngle(endAngle)
                    
                    // Save the offset from touch point to capsule center
                    let capsuleCenterAngle = (startAngle + endAngle) / 2
                    dragState.dragStartAngleOffset = angleDifference(tapAngle, capsuleCenterAngle)
                }
            } else {
                // Use current event position if no history
                // Calculate angles
                let startAngle = angleForTime(sleepEvent.date)
                let endAngle = angleForTime(sleepEvent.endTime)
                let tapAngle = angleFromPoint(value.startLocation, geometry: geometry)
                
                // Calculate distance from tap to start and end points
                let startDiff = angleDifference(tapAngle, startAngle)
                let endDiff = angleDifference(tapAngle, endAngle)
                
                // Determine drag mode based on proximity to start/end points
                if startDiff < 10 { // Within 10 degrees of start
                    dragState.dragMode = .startPoint
                    dragState.dragAngle = startAngle
                    dragState.dragTime = sleepEvent.date
                } else if endDiff < 10 { // Within 10 degrees of end
                    dragState.dragMode = .endPoint
                    dragState.dragEndAngle = endAngle
                    dragState.dragEndTime = sleepEvent.endTime
                } else {
                    // Dragging the whole sleep event
                    dragState.dragMode = .wholeSleep
                    dragState.dragAngle = startAngle
                    dragState.dragTime = sleepEvent.date
                    dragState.dragEndAngle = endAngle
                    dragState.dragEndTime = sleepEvent.endTime
                    
                    // Save the offset from touch point to capsule center
                    let capsuleCenterAngle = (startAngle + endAngle) / 2
                    dragState.dragStartAngleOffset = angleDifference(tapAngle, capsuleCenterAngle)
                }
            }
            
            // Store the event's original state when drag begins
            dataStore.saveCurrentStateForUndo(eventId: event.id, for: date)
            
            let generator = UIImpactFeedbackGenerator(style: .light)
            generator.impactOccurred()
        }
        
        // Calculate new angle directly from drag position
        let newAngle = angleFromPoint(value.location, geometry: geometry)
        
        // Get fresh wake and bedtime events for constraints
        let wakeEvent = findWakeEvent()
        let bedtimeEvent = findBedtimeEvent()
        let wakeTime = wakeEvent?.date ?? dataStore.baby.wakeTime
        let bedTime = bedtimeEvent?.date ?? dataStore.baby.bedTime
        
        // Use transaction to disable animations during drag
        var transaction = Transaction()
        transaction.disablesAnimations = true
        
        withTransaction(transaction) {
            // Update the core tracking properties first
            dragState.isDragging = true
            dragState.draggedEventId = event.id
            dragState.showConfirmationTime = false
            
            switch dragState.dragMode {
            case .startPoint:
                // Set angle first for smooth dragging
                dragState.dragAngle = newAngle
                
                // Then calculate the time from the angle
                let newTime = timeFromAngle(dragState.dragAngle)
                
                // Apply constraints to the time
                if newTime >= sleepEvent.endTime {
                    dragState.dragTime = sleepEvent.endTime.addingTimeInterval(-15 * 60)
                } else if newTime < wakeTime {
                    dragState.dragTime = wakeTime
                } else {
                    dragState.dragTime = newTime
                }
                
                // Recalculate angle after applying time constraints
                dragState.dragAngle = angleForTime(dragState.dragTime)
                
            case .endPoint:
                // Set angle first for smooth dragging
                dragState.dragEndAngle = newAngle
                
                // Then calculate the time from the angle
                let newTime = timeFromAngle(dragState.dragEndAngle)
                
                // Apply constraints to the time
                if newTime <= sleepEvent.date {
                    dragState.dragEndTime = sleepEvent.date.addingTimeInterval(15 * 60)
                } else if newTime > bedTime {
                    dragState.dragEndTime = bedTime
                } else {
                    dragState.dragEndTime = newTime
                }
                
                // Recalculate angle after applying time constraints
                dragState.dragEndAngle = angleForTime(dragState.dragEndTime)
                
            case .wholeSleep:
                // For whole capsule dragging, we need to calculate the center position
                // that should be at the current drag point
                
                // Calculate the duration to preserve
                let duration = dragState.originalEndTime.timeIntervalSince(dragState.originalStartTime)
                
                // Apply the saved offset to find the intended capsule center angle
                let adjustedAngle = newAngle
                
                // Calculate a new time based on this adjusted angle
                let newCenterTime = timeFromAngle(adjustedAngle)
                
                // Calculate half the duration in seconds
                let halfDuration = duration / 2
                
                // Calculate new start and end times based on the center
                let newStartTime = newCenterTime.addingTimeInterval(-halfDuration)
                let newEndTime = newCenterTime.addingTimeInterval(halfDuration)
                
                // Apply constraints
                // Start time constraint
                if newStartTime < wakeTime {
                    dragState.dragTime = wakeTime
                    dragState.dragEndTime = wakeTime.addingTimeInterval(duration)
                }
                // End time constraint
                else if newEndTime > bedTime {
                    dragState.dragEndTime = bedTime
                    dragState.dragTime = bedTime.addingTimeInterval(-duration)
                }
                // Both within bounds
                else {
                    dragState.dragTime = newStartTime
                    dragState.dragEndTime = newEndTime
                }
                
                // Recalculate angles after applying time constraints
                dragState.dragAngle = angleForTime(dragState.dragTime)
                dragState.dragEndAngle = angleForTime(dragState.dragEndTime)
            }
        }
    }
    
    private func handleSleepEventDragEnd(value: DragGesture.Value, event: Event) {
        
        guard dataStore.isEditingAllowed(for: date) else { return }
        
        // Recalculate angles based on current constraints
        dragState.dragAngle = angleForTime(dragState.dragTime)
        if dragState.dragMode == .endPoint || dragState.dragMode == .wholeSleep {
            dragState.dragEndAngle = angleForTime(dragState.dragEndTime)
        }
        
        // Update the data model based on drag mode
        switch dragState.dragMode {
        case .startPoint:
            updateSleepEventStartTime(event, to: dragState.dragTime)
            // Save the position
            DragState.lastKnownPositions[event.id] = (startAngle: dragState.dragAngle, endAngle: dragState.dragEndAngle)
        case .endPoint:
            updateSleepEventEndTime(event, to: dragState.dragEndTime)
            // Save the position
            DragState.lastKnownPositions[event.id] = (startAngle: angleForTime(dragState.dragTime), endAngle: dragState.dragEndAngle)
        case .wholeSleep:
            updateSleepEventWhole(event, startTime: dragState.dragTime, endTime: dragState.dragEndTime)
            // Save the position
            DragState.lastKnownPositions[event.id] = (startAngle: dragState.dragAngle, endAngle: dragState.dragEndAngle)
        }
        
        // Show confirmation
        withAnimation(.easeOut(duration: 0.2)) {
            dragState.isDragging = false
            dragState.showConfirmationTime = true
        }
        
        // Keep dragState.draggedEventId until confirmation is hidden
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            withAnimation(.easeOut(duration: 0.2)) {
                dragState.showConfirmationTime = false
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                if dragState.draggedEventId == event.id {
                    //dragState.draggedEventId = nil
                    dragState.reset()
                }
            }
        }
    }
    
    private func handleFeedEventDragChange(value: DragGesture.Value, event: Event, geometry: GeometryProxy) {
        
        guard dataStore.isEditingAllowed(for: date) else { return }
        
        // Store the event's original state when drag begins
        if !dragState.isDragging, let _ = dataStore.getFeedEvent(id: event.id, for: date) {
            // Use new method to save to undo stack
            dataStore.saveCurrentStateForUndo(eventId: event.id, for: date)
            
            // Store the initial touch location
            dragState.dragStartLocation = value.startLocation
            
            // Get the last known position if available
            if let lastPosition = DragState.lastKnownPositions[event.id] {
                // Start dragging from the last known position
                dragState.dragAngle = lastPosition.startAngle
                dragState.dragTime = timeFromAngle(lastPosition.startAngle)
            } else {
                // Use current event position if no history
                dragState.dragAngle = angleForTime(event.date)
                dragState.dragTime = event.date
            }
            
            let generator = UIImpactFeedbackGenerator(style: .light)
            generator.impactOccurred()
        }
        
        // Convert delta to angle change (based on circle geometry)
        let center = CGPoint(x: geometry.size.width / 2, y: geometry.size.height / 2)
        let startVector = CGPoint(x: dragState.dragStartLocation.x - center.x,
                                  y: dragState.dragStartLocation.y - center.y)
        let currentVector = CGPoint(x: value.location.x - center.x,
                                    y: value.location.y - center.y)
        
        // Calculate angle between vectors
        let startAngle = atan2(startVector.y, startVector.x)
        let currentAngle = atan2(currentVector.y, currentVector.x)
        
        // Apply angle change to starting angle
        let newAngle = angleFromPoint(value.location, geometry: geometry)
        let constrainedAngle = constrainAngleToArc(newAngle)
        let newTime = timeFromAngle(constrainedAngle)
        
        // Update UI state
        withAnimation(nil) { // No animation during drag movement
            dragState.isDragging = true
            dragState.draggedEventId = event.id
            dragState.dragMode = .wholeSleep // Default mode for feed events
            dragState.dragAngle = constrainedAngle
            dragState.dragTime = newTime
            dragState.showConfirmationTime = false
        }
        
    }
    
    private func handleFeedEventDragEnd(value: DragGesture.Value, event: Event) {
        
        guard dataStore.isEditingAllowed(for: date) else { return }
        
        // Update the data model
        updateEventTime(event, to: dragState.dragTime)
        
        // Store the final position for future dragging
        DragState.lastKnownPositions[event.id] = (startAngle: dragState.dragAngle, endAngle: nil)
        
        // Show confirmation with the same time
        // TODO: might be where error coming from
        withAnimation(.easeOut(duration: 0.2)) {
            dragState.isDragging = false
            dragState.showConfirmationTime = true
        }
        
        // Keep dragState.draggedEventId and dragState.dragTime until confirmation is hidden
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            withAnimation(.easeOut(duration: 0.2)) {
                dragState.showConfirmationTime = false
            }
            
            // Only reset the dragged event ID after confirmation disappears
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                if dragState.draggedEventId == event.id {
                    dragState.reset()
                    //dragState.draggedEventId = nil
                }
            }
        }
    }
    
    private func handleTaskEventDragChange(value: DragGesture.Value, event: Event, taskEvent: TaskEvent, geometry: GeometryProxy) {
        guard dataStore.isEditingAllowed(for: date) else { return }
        
        // First drag begins - determine drag mode
        if !dragState.isDragging {
            // Store original times for whole task dragging
            dragState.originalStartTime = taskEvent.date
            dragState.originalEndTime = taskEvent.endTime
            
            // Store the initial touch location
            dragState.dragStartLocation = value.startLocation
            
            // Get the last known position if available
            if let lastPosition = DragState.lastKnownPositions[event.id] {
                // Calculate angles
                let startAngle = lastPosition.startAngle
                let endAngle = lastPosition.endAngle ?? angleForTime(taskEvent.endTime)
                let tapAngle = angleFromPoint(value.startLocation, geometry: geometry)
                
                // Calculate distance from tap to start and end points
                let startDiff = angleDifference(tapAngle, startAngle)
                let endDiff = angleDifference(tapAngle, endAngle)
                
                // Determine drag mode based on proximity to start/end points
                if startDiff < 10 { // Within 10 degrees of start
                    dragState.dragMode = .startPoint
                    dragState.dragAngle = startAngle
                    dragState.dragTime = timeFromAngle(startAngle)
                } else if endDiff < 10 { // Within 10 degrees of end
                    dragState.dragMode = .endPoint
                    dragState.dragEndAngle = endAngle
                    dragState.dragEndTime = timeFromAngle(endAngle)
                } else {
                    // Otherwise, drag the whole task event
                    dragState.dragMode = .wholeSleep
                    dragState.dragAngle = startAngle
                    dragState.dragTime = timeFromAngle(startAngle)
                    dragState.dragEndAngle = endAngle
                    dragState.dragEndTime = timeFromAngle(endAngle)
                    
                    // Save the offset from touch point to capsule center
                    let capsuleCenterAngle = (startAngle + endAngle) / 2
                    dragState.dragStartAngleOffset = angleDifference(tapAngle, capsuleCenterAngle)
                }
            } else {
                // Use current event position if no history
                // Calculate angles
                let startAngle = angleForTime(taskEvent.date)
                let endAngle = angleForTime(taskEvent.endTime)
                let tapAngle = angleFromPoint(value.startLocation, geometry: geometry)
                
                // Calculate distance from tap to start and end points
                let startDiff = angleDifference(tapAngle, startAngle)
                let endDiff = angleDifference(tapAngle, endAngle)
                
                // Determine drag mode based on proximity to start/end points
                if startDiff < 10 { // Within 10 degrees of start
                    dragState.dragMode = .startPoint
                    dragState.dragAngle = startAngle
                    dragState.dragTime = taskEvent.date
                } else if endDiff < 10 { // Within 10 degrees of end
                    dragState.dragMode = .endPoint
                    dragState.dragEndAngle = endAngle
                    dragState.dragEndTime = taskEvent.endTime
                } else {
                    // Otherwise, drag the whole sleep event
                    dragState.dragMode = .wholeSleep
                    dragState.dragAngle = startAngle
                    dragState.dragTime = taskEvent.date
                    dragState.dragEndAngle = endAngle
                    dragState.dragEndTime = taskEvent.endTime
                    
                    // Save the offset from touch point to capsule center
                    let capsuleCenterAngle = (startAngle + endAngle) / 2
                    dragState.dragStartAngleOffset = angleDifference(tapAngle, capsuleCenterAngle)
                }
            }
            
            // Store the event's original state when drag begins
            dataStore.saveCurrentStateForUndo(eventId: event.id, for: date)
            
            let generator = UIImpactFeedbackGenerator(style: .light)
            generator.impactOccurred()
        }
        
        // Calculate new angle directly from drag position
        let newAngle = angleFromPoint(value.location, geometry: geometry)
        
        // Get fresh wake and bedtime events for constraints
        let wakeEvent = dataStore.findWakeEvent(for: date)
        let bedtimeEvent = dataStore.findBedtimeEvent(for: date)
        let wakeTime = wakeEvent?.date ?? dataStore.baby.wakeTime
        let bedTime = bedtimeEvent?.date ?? dataStore.baby.bedTime
        
        // Use transaction to disable animations during drag
        var transaction = Transaction()
        transaction.disablesAnimations = true
        
        withTransaction(transaction) {
            // Update core tracking properties
            dragState.isDragging = true
            dragState.draggedEventId = event.id
            dragState.showConfirmationTime = false
            
            switch dragState.dragMode {
            case .startPoint:
                // Set angle first for smooth dragging
                dragState.dragAngle = newAngle
                
                // Then calculate the time from the angle
                let newTime = timeFromAngle(dragState.dragAngle)
                
                // Apply constraints to the time
                if newTime >= taskEvent.endTime {
                    dragState.dragTime = taskEvent.endTime.addingTimeInterval(-15 * 60)
                } else if newTime < wakeTime {
                    dragState.dragTime = wakeTime
                } else {
                    dragState.dragTime = newTime
                }
                
                // Recalculate angle after applying time constraints
                dragState.dragAngle = angleForTime(dragState.dragTime)
                
            case .endPoint:
                // Set angle first for smooth dragging
                dragState.dragEndAngle = newAngle
                
                // Then calculate the time from the angle
                let newTime = timeFromAngle(dragState.dragEndAngle)
                
                // Apply constraints to the time
                if newTime <= taskEvent.date {
                    dragState.dragEndTime = taskEvent.date.addingTimeInterval(15 * 60)
                } else if newTime > bedTime {
                    dragState.dragEndTime = bedTime
                } else {
                    dragState.dragEndTime = newTime
                }
                
                // Recalculate angle after applying time constraints
                dragState.dragEndAngle = angleForTime(dragState.dragEndTime)
                
            case .wholeSleep: // Reusing the same enum for tasks
                // For whole capsule dragging, we need to calculate the center position
                // that should be at the current drag point
                
                // Calculate the duration to preserve
                let duration = dragState.originalEndTime.timeIntervalSince(dragState.originalStartTime)
                
                // Apply the saved offset to find the intended capsule center angle
                let adjustedAngle = newAngle
                
                // Calculate a new time based on this adjusted angle
                let newCenterTime = timeFromAngle(adjustedAngle)
                
                // Calculate half the duration in seconds
                let halfDuration = duration / 2
                
                // Calculate new start and end times based on the center
                let newStartTime = newCenterTime.addingTimeInterval(-halfDuration)
                let newEndTime = newCenterTime.addingTimeInterval(halfDuration)
                
                // Apply constraints
                // Start time constraint
                if newStartTime < wakeTime {
                    dragState.dragTime = wakeTime
                    dragState.dragEndTime = wakeTime.addingTimeInterval(duration)
                }
                // End time constraint
                else if newEndTime > bedTime {
                    dragState.dragEndTime = bedTime
                    dragState.dragTime = bedTime.addingTimeInterval(-duration)
                }
                // Both within bounds
                else {
                    dragState.dragTime = newStartTime
                    dragState.dragEndTime = newEndTime
                }
                
                // Recalculate angles after applying time constraints
                dragState.dragAngle = angleForTime(dragState.dragTime)
                dragState.dragEndAngle = angleForTime(dragState.dragEndTime)
            }
        }
    }
    
    private func handleTaskEventDragEnd(value: DragGesture.Value, event: Event) {
        
        guard dataStore.isEditingAllowed(for: date) else { return }
        
        // Get fresh wake and bedtime constraints before updating
        let wakeEvent = dataStore.findWakeEvent(for: date)
        let bedtimeEvent = dataStore.findBedtimeEvent(for: date)
        
        // Recalculate angles based on current constraints
        dragState.dragAngle = angleForTime(dragState.dragTime)
        if dragState.dragMode == .endPoint || dragState.dragMode == .wholeSleep {
            dragState.dragEndAngle = angleForTime(dragState.dragEndTime)
        }
        
        // Update the data model based on drag mode
        switch dragState.dragMode {
        case .startPoint:
            updateTaskEventStartTime(event, to: dragState.dragTime)
            // Store the final position for future dragging
            DragState.lastKnownPositions[event.id] = (startAngle: dragState.dragAngle, endAngle: angleForTime(dragState.dragEndTime))
        case .endPoint:
            updateTaskEventEndTime(event, to: dragState.dragEndTime)
            // Store the final position for future dragging
            DragState.lastKnownPositions[event.id] = (startAngle: angleForTime(dragState.dragTime), endAngle: dragState.dragEndAngle)
        case .wholeSleep: // Reusing this enum for tasks
            updateTaskEventWhole(event, startTime: dragState.dragTime, endTime: dragState.dragEndTime)
            // Store the final position for future dragging
            DragState.lastKnownPositions[event.id] = (startAngle: dragState.dragAngle, endAngle: dragState.dragEndAngle)
        }
        
        // Show confirmation
        withAnimation(.easeOut(duration: 0.2)) {
            dragState.isDragging = false
            dragState.showConfirmationTime = true
        }
        
        // Keep dragState.draggedEventId until confirmation is hidden
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            withAnimation(.easeOut(duration: 0.2)) {
                dragState.showConfirmationTime = false
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                if dragState.draggedEventId == event.id {
                    dragState.reset()
                }
            }
        }
    }
    
    // Add a method to clear positions when events are deleted
    private func clearPositionCache(for eventId: UUID) {
        DragState.lastKnownPositions.removeValue(forKey: eventId)
    }
    
    // MARK: - Helper Functions
    
    // Helper function to calculate the smallest angle between two angles
    private func angleDifference(_ angle1: Double, _ angle2: Double) -> Double {
        let diff = abs((angle1 - angle2).truncatingRemainder(dividingBy: 360))
        return min(diff, 360 - diff)
    }
    
    private func getSleepEventForDate(_ event: Event) -> SleepEvent? {
        let eventDate = Calendar.current.date(from: Calendar.current.dateComponents([.year, .month, .day], from: event.date))
        return eventDate.flatMap { dataStore.getSleepEvent(id: event.id, for: $0) }
    }
    
    private func getTaskEventForDate(_ event: Event) -> TaskEvent? {
        let eventDate = Calendar.current.date(from: Calendar.current.dateComponents([.year, .month, .day], from: event.date))
        return eventDate.flatMap { dataStore.getTaskEvent(id: event.id, for: $0) }
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    // Constrain angle to stay on the arc
    private func constrainAngleToArc(_ angle: Double) -> Double {
        // Convert angles to 0-360 range
        let normalizedStartAngle = (arcStartAngle + 360).truncatingRemainder(dividingBy: 360)
        let normalizedEndAngle = (arcEndAngle + 360).truncatingRemainder(dividingBy: 360)
        let normalizedAngle = (angle + 360).truncatingRemainder(dividingBy: 360)
        
        // Determine arc sweep based on clockwise or counterclockwise direction
        let arcSweep: Double
        if normalizedEndAngle > normalizedStartAngle {
            arcSweep = normalizedEndAngle - normalizedStartAngle
        } else {
            arcSweep = 360 - (normalizedStartAngle - normalizedEndAngle)
        }
        
        // For typical case where arc is less than 180 degrees
        if arcSweep < 180 {
            if (normalizedAngle < normalizedStartAngle || normalizedAngle > normalizedEndAngle) {
                // Out of bounds, constrain to closest end
                let startDist = min(abs(normalizedAngle - normalizedStartAngle),
                                    360 - abs(normalizedAngle - normalizedStartAngle))
                let endDist = min(abs(normalizedAngle - normalizedEndAngle),
                                  360 - abs(normalizedAngle - normalizedEndAngle))
                
                return startDist < endDist ? arcStartAngle : arcEndAngle
            }
        } else {
            // For arcs larger than 180 degrees
            if (normalizedAngle > normalizedEndAngle && normalizedAngle < normalizedStartAngle) {
                // Out of bounds, constrain to closest end
                let startDist = min(abs(normalizedAngle - normalizedStartAngle),
                                    360 - abs(normalizedAngle - normalizedStartAngle))
                let endDist = min(abs(normalizedAngle - normalizedEndAngle),
                                  360 - abs(normalizedAngle - normalizedEndAngle))
                
                return startDist < endDist ? arcStartAngle : arcEndAngle
            }
        }
        
        // Angle is within the arc, return as is
        return angle
    }
    
    // Helper method for getting a point precisely in the center of the donut width
    // This ensures circles stay on the arc
    private func pointOnDonutCenter(angle: Double, geometry: GeometryProxy) -> CGPoint {
        let center = CGPoint(x: geometry.size.width / 2, y: geometry.size.height / 2)
        // Calculate radius to the center of the donut's width
        let radius = min(geometry.size.width, geometry.size.height) / 2
        
        // Use angle as-is to ensure smooth dragging, but constrain it for display purposes
        let angleRadians = angle * .pi / 180
        
        let x = center.x + radius * cos(angleRadians)
        let y = center.y + radius * sin(angleRadians)
        
        return CGPoint(x: x, y: y)
    }
    
    // Helper method for getting a point outside the donut for labels
    private func pointOutsideDonut(angle: Double, geometry: GeometryProxy, offset: CGFloat) -> CGPoint {
        let center = CGPoint(x: geometry.size.width / 2, y: geometry.size.height / 2)
        // Calculate radius to the outside of the donut plus offset
        // Increase the offset to move labels further out from the donut
        let radius = (min(geometry.size.width, geometry.size.height) / 2) + (donutWidth / 2) + offset
        
        // Use constrained angle for consistent positioning
        let constrainedAngle = constrainAngleToArc(angle)
        let angleRadians = constrainedAngle * .pi / 180
        
        let x = center.x + radius * cos(angleRadians)
        let y = center.y + radius * sin(angleRadians)
        
        return CGPoint(x: x, y: y)
    }
    
    // Calculate angle from a point in the view
    private func angleFromPoint(_ point: CGPoint, geometry: GeometryProxy) -> Double {
        let center = CGPoint(x: geometry.size.width / 2, y: geometry.size.height / 2)
        
        // Calculate angle in radians
        let dx = point.x - center.x
        let dy = point.y - center.y
        
        var angle = atan2(dy, dx) * 180 / .pi
        
        // Normalize to 0-360 range
        if angle < 0 {
            angle += 360
        }
        
        return angle
    }
    
    // Calculate time from angle position
    private func timeFromAngle(_ angle: Double) -> Date {
        let calendar = Calendar.current
        
        // Get wake and bedtime
        let wakeEvent = findWakeEvent()
        let bedtimeEvent = findBedtimeEvent()
        let wakeTime = wakeEvent?.date ?? dataStore.baby.wakeTime
        let bedTime = bedtimeEvent?.date ?? dataStore.baby.bedTime
        
        let wakeComponents = calendar.dateComponents([.hour, .minute], from: wakeTime)
        let bedComponents = calendar.dateComponents([.hour, .minute], from: bedTime)
        
        guard let wakeHour = wakeComponents.hour, let wakeMinute = wakeComponents.minute,
              let bedHour = bedComponents.hour, let bedMinute = bedComponents.minute else {
            return Date() // Default if can't calculate
        }
        
        // Special handling for midnight bedtime (both 00:00 and 24:00)
        let isMidnightBedtime = (bedHour == 0 && bedMinute == 0) || (bedHour == 24 && bedMinute == 0)
        
        // Adjust bedtime minutes for calculations
        let bedTimeMinutes = bedHour * 60 + bedMinute
        let wakeTimeMinutes = wakeHour * 60 + wakeMinute
        
        // Handle special case for midnight bedtime
        let totalWakingMinutes: Int
        if isMidnightBedtime {
            // For midnight bedtime, calculate as if it's 23:59
            totalWakingMinutes = ((23 * 60) + 59) - wakeTimeMinutes
        } else if bedTimeMinutes > wakeTimeMinutes {
            // Normal same-day case
            totalWakingMinutes = bedTimeMinutes - wakeTimeMinutes
        } else {
            // Overnight case
            totalWakingMinutes = (24 * 60 - wakeTimeMinutes) + bedTimeMinutes
        }
        
        // Calculate the total angle sweep of the arc
        let totalAngleSweep = (arcEndAngle - arcStartAngle + 360).truncatingRemainder(dividingBy: 360)
        
        // Normalize the input angle relative to the arc's start angle
        var relativeAngle = (angle - arcStartAngle + 360).truncatingRemainder(dividingBy: 360)
        
        // Ensure relative angle is within arc sweep
        if relativeAngle > totalAngleSweep {
            relativeAngle = totalAngleSweep // Cap at the arc's end
        }
        
        // Convert normalized angle to time - CRITICAL calculation
        let normalizedTime = relativeAngle / totalAngleSweep
        let minutesSinceWake = Int(normalizedTime * Double(totalWakingMinutes))
        
        // Create a date with the correct time
        var dateComponents = calendar.dateComponents([.year, .month, .day], from: date)
        
        // The actual time derived from wake time plus minutes since wake
        let totalMinutes = wakeTimeMinutes + minutesSinceWake
        
        // Handle possible day overflow
        let hours = (totalMinutes / 60) % 24
        let minutes = totalMinutes % 60
        
        dateComponents.hour = hours
        dateComponents.minute = minutes
        
        // If we're past midnight, adjust the day
        if isMidnightBedtime && hours >= 0 && hours < wakeHour {
            dateComponents.day = (dateComponents.day ?? 0) + 1
        } else if !isMidnightBedtime && bedTimeMinutes < wakeTimeMinutes && hours < wakeHour {
            dateComponents.day = (dateComponents.day ?? 0) + 1
        }
        
        return calendar.date(from: dateComponents) ?? Date()
    }
    
    // Helper method to get current time mapped to today's date
    private func getCurrentTimeForToday() -> Date? {
        let now = Date()
        let calendar = Calendar.current
        
        let dateComponents = calendar.dateComponents([.year, .month, .day], from: date)
        let nowComponents = calendar.dateComponents([.hour, .minute], from: now)
        
        var combinedComponents = dateComponents
        combinedComponents.hour = nowComponents.hour
        combinedComponents.minute = nowComponents.minute
        
        return calendar.date(from: combinedComponents)
    }
    
    // Helper method to get a specific hour for today's date
    private func getTimeForHour(_ hour: Int) -> Date {
        let calendar = Calendar.current
        var components = calendar.dateComponents([.year, .month, .day], from: date)
        components.hour = hour
        components.minute = 0
        return calendar.date(from: components)!
    }
    
    private func angleForTime(_ time: Date) -> Double {
        let calendar = Calendar.current
        
        // ALWAYS get fresh values, never use cached values
        let wakeEvent = findWakeEvent()
        let bedtimeEvent = findBedtimeEvent()
        let wakeTime = wakeEvent?.date ?? dataStore.baby.wakeTime
        let bedTime = bedtimeEvent?.date ?? dataStore.baby.bedTime
        
        let wakeComponents = calendar.dateComponents([.hour, .minute], from: wakeTime)
        let bedComponents = calendar.dateComponents([.hour, .minute], from: bedTime)
        
        guard let wakeHour = wakeComponents.hour, let wakeMinute = wakeComponents.minute,
              let bedHour = bedComponents.hour, let bedMinute = bedComponents.minute else {
            return arcStartAngle // Default if can't calculate
        }
        
        // Special handling for midnight bedtime (both 00:00 and 24:00)
        let isMidnightBedtime = (bedHour == 0 && bedMinute == 0) || (bedHour == 24 && bedMinute == 0)
        
        let wakeTimeMinutes = wakeHour * 60 + wakeMinute
        let bedTimeMinutes = bedHour * 60 + bedMinute
        
        // Handle special case for midnight bedtime
        let totalWakingMinutes: Int
        if isMidnightBedtime {
            // For midnight bedtime, calculate as if it's 23:59
            totalWakingMinutes = ((23 * 60) + 59) - wakeTimeMinutes
        } else if bedTimeMinutes > wakeTimeMinutes {
            // Normal same-day case
            totalWakingMinutes = bedTimeMinutes - wakeTimeMinutes
        } else {
            // Overnight case
            totalWakingMinutes = (24 * 60 - wakeTimeMinutes) + bedTimeMinutes
        }
        
        let hourMinute = calendar.dateComponents([.hour, .minute], from: time)
        guard let hour = hourMinute.hour, let minute = hourMinute.minute else {
            return arcStartAngle
        }
        
        let timeMinutes = hour * 60 + minute
        
        // Calculate minutes since wake time, handling wrap-around at midnight if needed
        let minutesSinceWake: Int
        
        if isMidnightBedtime {
            // Special midnight bedtime handling
            if timeMinutes >= wakeTimeMinutes && timeMinutes <= (23 * 60 + 59) {
                minutesSinceWake = timeMinutes - wakeTimeMinutes
            } else {
                // Time is outside the wake window, clamp to nearest valid time
                if timeMinutes < wakeTimeMinutes {
                    minutesSinceWake = 0 // Clamp to wake time
                } else {
                    minutesSinceWake = totalWakingMinutes // Clamp to bedtime (23:59)
                }
            }
        } else if bedTimeMinutes > wakeTimeMinutes {
            // No overnight case
            if timeMinutes >= wakeTimeMinutes && timeMinutes <= bedTimeMinutes {
                minutesSinceWake = timeMinutes - wakeTimeMinutes
            } else {
                // Time is outside the wake window, clamp to nearest valid time
                if timeMinutes < wakeTimeMinutes {
                    minutesSinceWake = 0 // Clamp to wake time
                } else {
                    minutesSinceWake = totalWakingMinutes // Clamp to bedtime
                }
            }
        } else {
            // Overnight case (bedtime is tomorrow)
            if timeMinutes >= wakeTimeMinutes || timeMinutes <= bedTimeMinutes {
                // Time is within wake window
                if timeMinutes >= wakeTimeMinutes {
                    minutesSinceWake = timeMinutes - wakeTimeMinutes
                } else {
                    minutesSinceWake = (24 * 60 - wakeTimeMinutes) + timeMinutes
                }
            } else {
                // Time is outside wake window, clamp to nearest valid time
                if timeMinutes > bedTimeMinutes && timeMinutes < wakeTimeMinutes {
                    // Determine whether to clamp to wake or bedtime based on which is closer
                    let distanceToWake = wakeTimeMinutes - timeMinutes
                    let distanceToBed = timeMinutes - bedTimeMinutes
                    
                    if distanceToWake < distanceToBed {
                        minutesSinceWake = 0 // Clamp to wake time
                    } else {
                        minutesSinceWake = totalWakingMinutes // Clamp to bedtime
                    }
                } else {
                    minutesSinceWake = 0 // Default fallback
                }
            }
        }
        
        // Normalize to [0, 1] range within waking hours
        let normalizedTime = max(0, min(1, Double(minutesSinceWake) / Double(totalWakingMinutes)))
        
        // Calculate the total angle sweep of the arc, accounting for wrapping around 360
        let totalAngleSweep = (arcEndAngle - arcStartAngle + 360).truncatingRemainder(dividingBy: 360)
        
        // Map normalized time to angle position on the arc
        let angle = arcStartAngle + normalizedTime * totalAngleSweep
        
        return angle
    }
    
    private func isTimeWithinWakingHours(_ time: Date) -> Bool {
        let calendar = Calendar.current
        let wakeComponents = calendar.dateComponents([.hour, .minute], from: dataStore.baby.wakeTime)
        let bedComponents = calendar.dateComponents([.hour, .minute], from: dataStore.baby.bedTime)
        
        guard let wakeHour = wakeComponents.hour, let wakeMinute = wakeComponents.minute,
              let bedHour = bedComponents.hour, let bedMinute = bedComponents.minute else {
            return false
        }
        
        let wakeTimeMinutes = wakeHour * 60 + wakeMinute
        let bedTimeMinutes = bedHour * 60 + bedMinute
        
        let hourMinute = calendar.dateComponents([.hour, .minute], from: time)
        guard let hour = hourMinute.hour, let minute = hourMinute.minute else {
            return false
        }
        
        let timeMinutes = hour * 60 + minute
        
        // Handle case where bedtime is after midnight
        if bedTimeMinutes > wakeTimeMinutes {
            return timeMinutes >= wakeTimeMinutes && timeMinutes <= bedTimeMinutes
        } else {
            // Bedtime is next day
            return timeMinutes >= wakeTimeMinutes || timeMinutes <= bedTimeMinutes
        }
    }
    
    private func colorForEvent(_ event: Event) -> Color {
        switch event.type {
        case .feed:
            return .blue
        case .sleep:
            if let eventDate = Calendar.current.date(from: Calendar.current.dateComponents([.year, .month, .day], from: event.date)),
               let sleepEvent = dataStore.getSleepEvent(id: event.id, for: eventDate) {
                switch sleepEvent.sleepType {
                case .nap:
                    return .purple
                case .bedtime:
                    return .indigo
                case .waketime:
                    return .orange
                }
            }
            return .green
        case .task:
            return .yellow
        case .goal:
            return .green
        }
    }
    
    // Update the event time based on dragging (for feed events)
    private func updateEventTime(_ event: Event, to newTime: Date) {
        // Preserve the original date but update the time
        let calendar = Calendar.current
        let dateComponents = calendar.dateComponents([.year, .month, .day], from: date)
        let timeComponents = calendar.dateComponents([.hour, .minute], from: newTime)
        
        var updatedComponents = dateComponents
        updatedComponents.hour = timeComponents.hour
        updatedComponents.minute = timeComponents.minute
        
        guard let updatedDate = calendar.date(from: updatedComponents) else { return }
        
        switch event.type {
        case .feed:
            if let feedEvent = dataStore.getFeedEvent(id: event.id, for: date) {
                // Calculate time difference between old and new times
                let timeDifference = updatedDate.timeIntervalSince(feedEvent.date)
                
                // Create updated feed event with new time
                let updatedFeedEvent = FeedEvent(
                    id: feedEvent.id,
                    date: updatedDate,
                    amount: feedEvent.amount,
                    breastMilkPercentage: feedEvent.breastMilkPercentage,
                    formulaPercentage: feedEvent.formulaPercentage,
                    // Adjust preparation time by the same amount
                    preparationTime: feedEvent.preparationTime.addingTimeInterval(timeDifference),
                    notes: feedEvent.notes,
                    isTemplate: feedEvent.isTemplate
                )
                
                // Update the event
                dataStore.updateFeedEvent(updatedFeedEvent, for: date)
            }
            
        case .sleep:
            if let sleepEvent = dataStore.getSleepEvent(id: event.id, for: date) {
                // Calculate time difference between old and new times
                let timeDifference = updatedDate.timeIntervalSince(sleepEvent.date)
                
                // Create updated sleep event with new time
                let updatedSleepEvent = SleepEvent(
                    id: sleepEvent.id,
                    date: updatedDate,
                    sleepType: sleepEvent.sleepType,
                    // Adjust end time by the same amount to maintain duration
                    endTime: sleepEvent.endTime.addingTimeInterval(timeDifference),
                    notes: sleepEvent.notes,
                    isTemplate: sleepEvent.isTemplate
                )
                
                // Update the event
                dataStore.updateSleepEvent(updatedSleepEvent, for: date)
            }
        case .task:
            break
        case .goal:
            break
        }
        
        // Provide haptic feedback for successful drag
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
    }
    
    // Update only the start time of a sleep event
    private func updateSleepEventStartTime(_ event: Event, to newStartTime: Date) {
        if event.type == .sleep,
           let sleepEvent = getSleepEventForDate(event) {
            
            // Preserve the original date but update the time
            let calendar = Calendar.current
            let dateComponents = calendar.dateComponents([.year, .month, .day], from: date)
            let timeComponents = calendar.dateComponents([.hour, .minute], from: newStartTime)
            
            var updatedComponents = dateComponents
            updatedComponents.hour = timeComponents.hour
            updatedComponents.minute = timeComponents.minute
            
            guard let updatedStartDate = calendar.date(from: updatedComponents) else { return }
            
            // Ensure the start time is before the end time
            if updatedStartDate >= sleepEvent.endTime {
                // If the user dragged the start time after the end time,
                // make it 15 minutes before the end time
                let updatedStartTime = sleepEvent.endTime.addingTimeInterval(-15 * 60)
                
                // Create updated sleep event with new start time
                let updatedSleepEvent = SleepEvent(
                    id: sleepEvent.id,
                    date: updatedStartTime,
                    sleepType: sleepEvent.sleepType,
                    endTime: sleepEvent.endTime,
                    notes: sleepEvent.notes,
                    isTemplate: sleepEvent.isTemplate
                )
                
                let (validStartDate, validEndDate) = validateSleepEventTimes(
                    startTime: updatedSleepEvent.date,
                    endTime: updatedSleepEvent.endTime
                )
                
                let finalUpdatedSleepEvent = SleepEvent(
                    id: updatedSleepEvent.id,
                    date: validStartDate,
                    sleepType: updatedSleepEvent.sleepType,
                    endTime: validEndDate,
                    notes: updatedSleepEvent.notes,
                    isTemplate: updatedSleepEvent.isTemplate,
                    isOngoing: updatedSleepEvent.isOngoing,
                    isPaused: updatedSleepEvent.isPaused,
                    pauseIntervals: updatedSleepEvent.pauseIntervals,
                    lastPauseTime: updatedSleepEvent.lastPauseTime
                )
                
                // Update the event
                dataStore.updateSleepEvent(finalUpdatedSleepEvent, for: date)
                
            } else {
                // Create updated sleep event with new start time
                let updatedSleepEvent = SleepEvent(
                    id: sleepEvent.id,
                    date: updatedStartDate,
                    sleepType: sleepEvent.sleepType,
                    endTime: sleepEvent.endTime,
                    notes: sleepEvent.notes,
                    isTemplate: sleepEvent.isTemplate
                )
                
                // Update the event
                dataStore.updateSleepEvent(updatedSleepEvent, for: date)
            }
            
            // Provide haptic feedback for successful drag
            let generator = UIImpactFeedbackGenerator(style: .medium)
            generator.impactOccurred()
        }
    }
    
    // Update only the end time of a sleep event
    private func updateSleepEventEndTime(_ event: Event, to newEndTime: Date) {
        if event.type == .sleep,
           let sleepEvent = getSleepEventForDate(event) {
            
            // Preserve the original date but update the time
            let calendar = Calendar.current
            let dateComponents = calendar.dateComponents([.year, .month, .day], from: date)
            let timeComponents = calendar.dateComponents([.hour, .minute], from: newEndTime)
            
            var updatedComponents = dateComponents
            updatedComponents.hour = timeComponents.hour
            updatedComponents.minute = timeComponents.minute
            
            guard let updatedEndDate = calendar.date(from: updatedComponents) else { return }
            
            // Ensure the end time is after the start time
            if updatedEndDate <= sleepEvent.date {
                // If the user dragged the end time before the start time,
                // make it at least 15 minutes after the start time
                let updatedEndTime = sleepEvent.date.addingTimeInterval(15 * 60)
                
                // Create updated sleep event with new end time
                let updatedSleepEvent = SleepEvent(
                    id: sleepEvent.id,
                    date: sleepEvent.date,
                    sleepType: sleepEvent.sleepType,
                    endTime: updatedEndTime,
                    notes: sleepEvent.notes,
                    isTemplate: sleepEvent.isTemplate
                )
                
                // Update the event
                dataStore.updateSleepEvent(updatedSleepEvent, for: date)
            } else {
                // Create updated sleep event with new end time
                let updatedSleepEvent = SleepEvent(
                    id: sleepEvent.id,
                    date: sleepEvent.date,
                    sleepType: sleepEvent.sleepType,
                    endTime: updatedEndDate,
                    notes: sleepEvent.notes,
                    isTemplate: sleepEvent.isTemplate
                )
                
                // Update the event
                dataStore.updateSleepEvent(updatedSleepEvent, for: date)
            }
            
            // Provide haptic feedback for successful drag
            let generator = UIImpactFeedbackGenerator(style: .medium)
            generator.impactOccurred()
        }
    }
    
    // Update both start and end times of a sleep event, maintaining original duration
    private func updateSleepEventWhole(_ event: Event, startTime: Date, endTime: Date) {
        if event.type == .sleep,
           let sleepEvent = getSleepEventForDate(event) {
            
            // Preserve the original date but update the times
            let calendar = Calendar.current
            let dateComponents = calendar.dateComponents([.year, .month, .day], from: date)
            
            let startTimeComponents = calendar.dateComponents([.hour, .minute], from: startTime)
            var updatedStartComponents = dateComponents
            updatedStartComponents.hour = startTimeComponents.hour
            updatedStartComponents.minute = startTimeComponents.minute
            
            let endTimeComponents = calendar.dateComponents([.hour, .minute], from: endTime)
            var updatedEndComponents = dateComponents
            updatedEndComponents.hour = endTimeComponents.hour
            updatedEndComponents.minute = endTimeComponents.minute
            
            guard let updatedStartDate = calendar.date(from: updatedStartComponents),
                  let updatedEndDate = calendar.date(from: updatedEndComponents) else { return }
            
            // Apply validation constraints
            let (validStartDate, validEndDate) = validateSleepEventTimes(
                startTime: updatedStartDate,
                endTime: updatedEndDate
            )
            
            // Create updated sleep event with new times
            let updatedSleepEvent = SleepEvent(
                id: sleepEvent.id,
                date: validStartDate,
                sleepType: sleepEvent.sleepType,
                endTime: validEndDate,
                notes: sleepEvent.notes,
                isTemplate: sleepEvent.isTemplate,
                isOngoing: sleepEvent.isOngoing,
                isPaused: sleepEvent.isPaused,
                pauseIntervals: sleepEvent.pauseIntervals,
                lastPauseTime: sleepEvent.lastPauseTime
            )
            
            // Update the event
            dataStore.updateSleepEvent(updatedSleepEvent, for: date)
            
            // Provide haptic feedback for successful drag
            let generator = UIImpactFeedbackGenerator(style: .medium)
            generator.impactOccurred()
        }
    }
    
    // Helper methods for updating task events
    func updateTaskEventStartTime(_ event: Event, to newStartTime: Date) {
        if event.type == .task,
           let taskEvent = getTaskEventForDate(event) {
            
            // Preserve the original date but update the time
            let calendar = Calendar.current
            let dateComponents = calendar.dateComponents([.year, .month, .day], from: date)
            let timeComponents = calendar.dateComponents([.hour, .minute], from: newStartTime)
            
            var updatedComponents = dateComponents
            updatedComponents.hour = timeComponents.hour
            updatedComponents.minute = timeComponents.minute
            
            guard let updatedStartDate = calendar.date(from: updatedComponents) else { return }
            
            // Ensure the start time is before the end time
            if updatedStartDate >= taskEvent.endTime {
                // If the user dragged the start time after the end time,
                // make it 15 minutes before the end time
                let updatedStartTime = taskEvent.endTime.addingTimeInterval(-15 * 60)
                
                // Create updated task event with new start time
                let updatedTaskEvent = TaskEvent(
                    id: taskEvent.id,
                    date: updatedStartTime,
                    title: taskEvent.title,
                    endTime: taskEvent.endTime,
                    notes: taskEvent.notes,
                    isTemplate: taskEvent.isTemplate,
                    completed: taskEvent.completed,
                    isOngoing: taskEvent.isOngoing
                )
                
                // Update the event
                dataStore.updateTaskEvent(updatedTaskEvent, for: date)
            } else {
                // Create updated task event with new start time
                let updatedTaskEvent = TaskEvent(
                    id: taskEvent.id,
                    date: updatedStartDate,
                    title: taskEvent.title,
                    endTime: taskEvent.endTime,
                    notes: taskEvent.notes,
                    isTemplate: taskEvent.isTemplate,
                    completed: taskEvent.completed,
                    isOngoing: taskEvent.isOngoing
                )
                
                // Update the event
                dataStore.updateTaskEvent(updatedTaskEvent, for: date)
            }
            
            // Provide haptic feedback for successful drag
            let generator = UIImpactFeedbackGenerator(style: .medium)
            generator.impactOccurred()
        }
    }
    
    func updateTaskEventEndTime(_ event: Event, to newEndTime: Date) {
        if event.type == .task,
           let taskEvent = getTaskEventForDate(event) {
            
            // Preserve the original date but update the time
            let calendar = Calendar.current
            let dateComponents = calendar.dateComponents([.year, .month, .day], from: date)
            let timeComponents = calendar.dateComponents([.hour, .minute], from: newEndTime)
            
            var updatedComponents = dateComponents
            updatedComponents.hour = timeComponents.hour
            updatedComponents.minute = timeComponents.minute
            
            guard let updatedEndDate = calendar.date(from: updatedComponents) else { return }
            
            // Ensure the end time is after the start time
            if updatedEndDate <= taskEvent.date {
                // If the user dragged the end time before the start time,
                // make it at least 15 minutes after the start time
                let updatedEndTime = taskEvent.date.addingTimeInterval(15 * 60)
                
                // Create updated task event with new end time
                let updatedTaskEvent = TaskEvent(
                    id: taskEvent.id,
                    date: taskEvent.date,
                    title: taskEvent.title,
                    endTime: updatedEndTime,
                    notes: taskEvent.notes,
                    isTemplate: taskEvent.isTemplate,
                    completed: taskEvent.completed,
                    isOngoing: taskEvent.isOngoing
                )
                
                // Update the event
                dataStore.updateTaskEvent(updatedTaskEvent, for: date)
            } else {
                // Create updated task event with new end time
                let updatedTaskEvent = TaskEvent(
                    id: taskEvent.id,
                    date: taskEvent.date,
                    title: taskEvent.title,
                    endTime: updatedEndDate,
                    notes: taskEvent.notes,
                    isTemplate: taskEvent.isTemplate,
                    completed: taskEvent.completed,
                    isOngoing: taskEvent.isOngoing
                )
                
                // Update the event
                dataStore.updateTaskEvent(updatedTaskEvent, for: date)
            }
            
            // Provide haptic feedback for successful drag
            let generator = UIImpactFeedbackGenerator(style: .medium)
            generator.impactOccurred()
        }
    }
    
    func updateTaskEventWhole(_ event: Event, startTime: Date, endTime: Date) {
        if event.type == .task,
           let taskEvent = getTaskEventForDate(event) {
            
            // Preserve the original date but update the times
            let calendar = Calendar.current
            let dateComponents = calendar.dateComponents([.year, .month, .day], from: date)
            
            let startTimeComponents = calendar.dateComponents([.hour, .minute], from: startTime)
            var updatedStartComponents = dateComponents
            updatedStartComponents.hour = startTimeComponents.hour
            updatedStartComponents.minute = startTimeComponents.minute
            
            let endTimeComponents = calendar.dateComponents([.hour, .minute], from: endTime)
            var updatedEndComponents = dateComponents
            updatedEndComponents.hour = endTimeComponents.hour
            updatedEndComponents.minute = endTimeComponents.minute
            
            guard let updatedStartDate = calendar.date(from: updatedStartComponents),
                  let updatedEndDate = calendar.date(from: updatedEndComponents) else { return }
            
            // Apply validation constraints
            let (validStartDate, validEndDate) = dataStore.validateEventTimes(
                startTime: updatedStartDate,
                endTime: updatedEndDate,
                for: date
            )
            
            // Create updated task event with new times
            let updatedTaskEvent = TaskEvent(
                id: taskEvent.id,
                date: validStartDate,
                title: taskEvent.title,
                endTime: validEndDate,
                notes: taskEvent.notes,
                isTemplate: taskEvent.isTemplate,
                completed: taskEvent.completed,
                isOngoing: taskEvent.isOngoing
            )
            
            // Update the event
            dataStore.updateTaskEvent(updatedTaskEvent, for: date)
            
            // Provide haptic feedback for successful drag
            let generator = UIImpactFeedbackGenerator(style: .medium)
            generator.impactOccurred()
        }
    }
    
    // Helper methods for wake and bedtime events
    private func findWakeEvent() -> SleepEvent? {
        let dateString = dataStore.formatDate(date)
        let sleepEvents = dataStore.sleepEvents[dateString] ?? []
        return sleepEvents.first(where: { $0.sleepType == .waketime })
    }
    
    private func findBedtimeEvent() -> SleepEvent? {
        let dateString = dataStore.formatDate(date)
        let sleepEvents = dataStore.sleepEvents[dateString] ?? []
        return sleepEvents.first(where: { $0.sleepType == .bedtime })
    }
    
    private func createDefaultWakeEvent() {
        
        if !dataStore.isEditingAllowed(for: date) {
            showLockFeedback()
            return
        }
        
        let calendar = Calendar.current
        var wakeTimeComponents = calendar.dateComponents([.year, .month, .day], from: date)
        let babyWakeTimeComponents = calendar.dateComponents([.hour, .minute], from: dataStore.baby.wakeTime)
        wakeTimeComponents.hour = babyWakeTimeComponents.hour
        wakeTimeComponents.minute = babyWakeTimeComponents.minute
        
        if let wakeDateTime = calendar.date(from: wakeTimeComponents) {
            let wakeEvent = SleepEvent(
                date: wakeDateTime,
                sleepType: .waketime,
                endTime: wakeDateTime.addingTimeInterval(30 * 60),
                isTemplate: false
            )
            
            // Add the event to the data store
            dataStore.addSleepEvent(wakeEvent, for: date)
            
            // Set as selected event to edit it
            selectedEvent = wakeEvent.toEvent()
        }
    }
    
    private func createDefaultBedtimeEvent() {
        
        if !dataStore.isEditingAllowed(for: date) {
            showLockFeedback()
            return
        }
        
        let calendar = Calendar.current
        var bedTimeComponents = calendar.dateComponents([.year, .month, .day], from: date)
        let babyBedTimeComponents = calendar.dateComponents([.hour, .minute], from: dataStore.baby.bedTime)
        bedTimeComponents.hour = babyBedTimeComponents.hour
        bedTimeComponents.minute = babyBedTimeComponents.minute
        
        if let bedDateTime = calendar.date(from: bedTimeComponents) {
            // End time is the next morning's wake time
            var nextDay = calendar.dateComponents([.year, .month, .day], from: date)
            nextDay.day = (nextDay.day ?? 0) + 1
            var nextWakeTimeComponents = nextDay
            
            let babyWakeTimeComponents = calendar.dateComponents([.hour, .minute], from: dataStore.baby.wakeTime)
            nextWakeTimeComponents.hour = babyWakeTimeComponents.hour
            nextWakeTimeComponents.minute = babyWakeTimeComponents.minute
            
            let nextWakeDateTime = calendar.date(from: nextWakeTimeComponents) ?? bedDateTime.addingTimeInterval(10 * 3600)
            
            let bedEvent = SleepEvent(
                date: bedDateTime,
                sleepType: .bedtime,
                endTime: nextWakeDateTime,
                isTemplate: false
            )
            
            // Add the event to the data store
            dataStore.addSleepEvent(bedEvent, for: date)
            
            // Set as selected event to edit it
            selectedEvent = bedEvent.toEvent()
        }
    }
    
    // Method to check for ongoing naps
    private func checkForOngoingNaps() {
        // Only check for today
        if Calendar.current.isDateInToday(date) {
            // Get all ongoing sleep events for today
            let ongoingNaps = dataStore.getOngoingSleepEvents(for: date).filter { $0.sleepType == .nap }
            
            // If there's an ongoing nap, set it as the active event
            if let ongoingNap = ongoingNaps.first {
                // Only update if this is a different nap than what we're already tracking
                // or if we don't have an active event yet
                if lastActiveNapId != ongoingNap.id || currentActiveEvent == nil {
                    print("Setting currentActiveEvent to nap: \(ongoingNap.id)")
                    currentActiveEvent = ActiveEvent.from(sleepEvent: ongoingNap)
                    lastActiveNapId = ongoingNap.id
                }
            } else if currentActiveEvent != nil {
                // Clear any existing active event if there are no ongoing naps
                print("Clearing currentActiveEvent")
                currentActiveEvent = nil
                lastActiveNapId = nil
            }
        }
    }
    
    private func showLockFeedback() {
        // Provide haptic feedback
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.warning)
        
        // Show lock overlay animation
        withAnimation(.spring()) {
            showLockAnimation = true
        }
    }
}

struct PulsingCircle: View {
    var color: Color
    var size: CGFloat
    var isPaused: Bool
    
    @State private var isAnimating = false
    
    var body: some View {
        ZStack {
            // Main circle
            Circle()
                .fill(color)
                .frame(width: size, height: size)
            
            // Pulsing circle - only animate if not paused
            Circle()
                .stroke(color, lineWidth: 2)
                .frame(width: size * (isAnimating ? 1.3 : 1.0),
                       height: size * (isAnimating ? 1.3 : 1.0))
                .opacity(isAnimating ? 0 : 0.7)
            
            // For paused state, show a "paused" indicator
            if isPaused {
                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.7))
                        .frame(width: size * 0.7, height: size * 0.7)
                    
                    // Pause icon (two vertical bars)
                    HStack(spacing: 4) {
                        Rectangle()
                            .fill(color)
                            .frame(width: 3, height: size * 0.3)
                        
                        Rectangle()
                            .fill(color)
                            .frame(width: 3, height: size * 0.3)
                    }
                }
            }
        }
        .onAppear {
            // Only animate if not paused
            if !isPaused {
                startAnimation()
            }
        }
        .onChange(of: isPaused) { _, newIsPaused in
            if newIsPaused {
                // Stop animation
                isAnimating = false
            } else {
                // Resume animation
                startAnimation()
            }
        }
    }
    
    private func startAnimation() {
        withAnimation(Animation.easeInOut(duration: 1.2).repeatForever(autoreverses: false)) {
            isAnimating = true
        }
    }
}

struct SleepArcCapsule: View {
    var startAngle: Double
    var endAngle: Double
    var donutWidth: CGFloat
    var color: Color
    var isOngoing: Bool = false
    var isPaused: Bool = false
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Base capsule shape
                ArcCapsuleShape(
                    startAngle: startAngle,
                    endAngle: endAngle,
                    donutWidth: donutWidth
                )
                .fill(color)
                
                // Overlay for ongoing events
                /*
                 if isOngoing && !isPaused {
                 OngoingEventOverlay(color: color)
                 .frame(width: geometry.size.width, height: geometry.size.height)
                 }
                 */
                
                // Overlay for paused events
                /*
                 if isPaused {
                 PausedEventOverlay(
                 startAngle: startAngle,
                 endAngle: endAngle,
                 donutWidth: donutWidth
                 )
                 .zIndex(2)
                 .frame(width: geometry.size.width, height: geometry.size.height)
                 }
                 */
            }
        }
    }
}

// Optimized TaskArcCapsule
struct TaskArcCapsule: View {
    var startAngle: Double
    var endAngle: Double
    var donutWidth: CGFloat
    var color: Color
    var isCompleted: Bool = false
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Base capsule shape
                ArcCapsuleShape(
                    startAngle: startAngle,
                    endAngle: endAngle,
                    donutWidth: donutWidth
                )
                .fill(color)
                .opacity(isCompleted ? 0.5 : 1.0)
                
                // Add checkmarks for completed tasks
                if isCompleted {
                    CheckmarksOverlay(
                        startAngle: startAngle,
                        endAngle: endAngle,
                        width: geometry.size.width,
                        height: geometry.size.height
                    )
                }
            }
        }
    }
}

// MARK: - Helper Components

struct LockFeedbackOverlay: View {
    @Binding var isVisible: Bool
    
    var body: some View {
        ZStack {
            Circle()
                .fill(Color.black.opacity(0.4))
                .frame(width: 80, height: 80)
            
            Image(systemName: "lock.fill")
                .font(.system(size: 30))
                .foregroundColor(.white)
        }
        .opacity(isVisible ? 1.0 : 0.0)
        .scaleEffect(isVisible ? 1.0 : 0.5)
        .onChange(of: isVisible) { _, newValue in
            if newValue {
                // Auto-hide after 1 second
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    withAnimation(.easeOut(duration: 0.3)) {
                        isVisible = false
                    }
                }
            }
        }
    }
}

// Shared base arc capsule shape
struct ArcCapsuleShape: Shape {
    var startAngle: Double
    var endAngle: Double
    var donutWidth: CGFloat
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let center = CGPoint(x: rect.width / 2, y: rect.height / 2)
        let radius = min(rect.width, rect.height) / 2
        
        // Calculate inner and outer radius
        let innerRadius = radius - donutWidth / 2
        let outerRadius = radius + donutWidth / 2
        
        // Convert angles to radians
        let startRad = startAngle * .pi / 180
        let endRad = endAngle * .pi / 180
        
        // Handle special case when angles complete a full circle
        let isFullCircle = abs(endAngle - startAngle) >= 360
        
        if isFullCircle {
            // Draw a full circle
            path.addEllipse(in: CGRect(
                x: center.x - radius,
                y: center.y - radius,
                width: radius * 2,
                height: radius * 2
            ))
        } else {
            // Calculate start and end points on inner and outer circles
            let startOuterX = center.x + outerRadius * cos(startRad)
            let startOuterY = center.y + outerRadius * sin(startRad)
            
            let endInnerX = center.x + innerRadius * cos(endRad)
            let endInnerY = center.y + innerRadius * sin(endRad)
            
            // Move to start point on outer circle
            path.move(to: CGPoint(x: startOuterX, y: startOuterY))
            
            // Add arc along outer circle
            path.addArc(
                center: center,
                radius: outerRadius,
                startAngle: Angle(radians: startRad),
                endAngle: Angle(radians: endRad),
                clockwise: false
            )
            
            // Line to inner circle
            path.addLine(to: CGPoint(x: endInnerX, y: endInnerY))
            
            // Arc back along inner circle
            path.addArc(
                center: center,
                radius: innerRadius,
                startAngle: Angle(radians: endRad),
                endAngle: Angle(radians: startRad),
                clockwise: true
            )
            
            // Close the path
            path.closeSubpath()
        }
        
        return path
    }
}

// Overlay for paused events with diagonal lines
struct PausedEventOverlay: View {
    var startAngle: Double
    var endAngle: Double
    var donutWidth: CGFloat
    
    var body: some View {
        ZStack {
            // Diagonal line pattern for paused state
            DiagonalLinesView(donutWidth: donutWidth)
                .mask(
                    ArcCapsuleShape(
                        startAngle: startAngle,
                        endAngle: endAngle,
                        donutWidth: donutWidth
                    )
                )
        }
    }
}

// Diagonal lines component for paused state
struct DiagonalLinesView: View {
    var donutWidth: CGFloat
    
    var body: some View {
        ZStack {
            ForEach(0..<15, id: \.self) { i in
                HStack(spacing: 10) {
                    ForEach(0..<2, id: \.self) { j in
                        Rectangle()
                            .fill(Color.white.opacity(0.4))
                            .frame(width: 1, height: donutWidth * 0.8)
                            .rotationEffect(.degrees(45))
                    }
                }
                .offset(x: CGFloat(i * 20) - 150)
            }
        }
    }
}

// Checkmarks overlay for completed tasks
struct CheckmarksOverlay: View {
    var startAngle: Double
    var endAngle: Double
    var width: CGFloat
    var height: CGFloat
    
    var body: some View {
        ForEach(0..<5, id: \.self) { i in
            CheckmarkView(
                index: i,
                startAngle: startAngle,
                endAngle: endAngle,
                width: width,
                height: height
            )
        }
    }
}

// Individual checkmark for the task
struct CheckmarkView: View {
    var index: Int
    var startAngle: Double
    var endAngle: Double
    var width: CGFloat
    var height: CGFloat
    
    var body: some View {
        let middleAngle = startAngle + (endAngle - startAngle) * Double(index) / 4.0
        let angleRadians = middleAngle * .pi / 180
        let center = CGPoint(x: width / 2, y: height / 2)
        let radius = min(width, height) / 2
        
        // Calculate position for this checkmark
        let x = center.x + radius * cos(angleRadians)
        let y = center.y + radius * sin(angleRadians)
        
        Image(systemName: "checkmark")
            .font(.system(size: 10))
            .foregroundColor(.white)
            .position(x: x, y: y)
    }
}

struct Arc: Shape {
    var startAngle: Angle
    var endAngle: Angle
    var clockwise: Bool
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = min(rect.width, rect.height) / 2
        
        path.addArc(center: center, radius: radius, startAngle: startAngle, endAngle: endAngle, clockwise: clockwise)
        
        return path
    }
}

struct PreciseArcStroke: UIViewRepresentable {
    var startAngle: Double
    var endAngle: Double
    var clockwise: Bool
    var lineWidth: CGFloat
    var color: Color
    var onDoubleTap: ((Double) -> Void)
    var date: Date
    @EnvironmentObject var dataStore: DataStore
    
    func makeUIView(context: Context) -> ArcTouchView {
        let view = ArcTouchView(
            startAngle: startAngle,
            endAngle: endAngle,
            clockwise: clockwise,
            lineWidth: lineWidth,
            color: UIColor(color)
        )
        view.onDoubleTap = onDoubleTap
        view.clipsToBounds = false
        view.date = date
        view.dataStore = dataStore  // Pass directly now
        return view
    }
    
    func updateUIView(_ uiView: ArcTouchView, context: Context) {
        uiView.startAngle = startAngle
        uiView.endAngle = endAngle
        uiView.clockwise = clockwise
        uiView.lineWidth = lineWidth
        uiView.color = UIColor(color)
        uiView.onDoubleTap = onDoubleTap
        uiView.date = date
        uiView.dataStore = dataStore  // Update directly
        uiView.setNeedsDisplay()
    }
    
    // UIKit view that can detect exact tap positions
    class ArcTouchView: UIView {
        var startAngle: Double
        var endAngle: Double
        var clockwise: Bool
        var lineWidth: CGFloat
        var color: UIColor
        var onDoubleTap: ((Double) -> Void)?
        var date: Date? // Add date property
        weak var dataStore: DataStore? // Add dataStore property
        
        init(startAngle: Double, endAngle: Double, clockwise: Bool, lineWidth: CGFloat, color: UIColor) {
            self.startAngle = startAngle
            self.endAngle = endAngle
            self.clockwise = clockwise
            self.lineWidth = lineWidth
            self.color = color
            self.date = nil // Initialize with nil
            self.dataStore = nil // Initialize with nil
            super.init(frame: .zero)
            
            // Setup gesture recognizer
            let doubleTapGesture = UITapGestureRecognizer(target: self, action: #selector(handleDoubleTap(_:)))
            doubleTapGesture.numberOfTapsRequired = 2
            self.addGestureRecognizer(doubleTapGesture)
            
            // Make sure we can receive touch events
            self.isUserInteractionEnabled = true
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        @objc func handleDoubleTap(_ gestureRecognizer: UITapGestureRecognizer) {
            // Guard against tap handling when editing is disabled
            if let dataStore = self.dataStore, let date = self.date, !dataStore.isEditingAllowed(for: date) {
                // Provide feedback when attempting to interact with locked past date
                let generator = UINotificationFeedbackGenerator()
                generator.notificationOccurred(.warning)
                return
            }
            
            let tapLocation = gestureRecognizer.location(in: self)
            let center = CGPoint(x: bounds.midX, y: bounds.midY)
            
            // Calculate angle in radians
            let dx = tapLocation.x - center.x
            let dy = tapLocation.y - center.y
            
            var angle = atan2(dy, dx) * 180 / .pi
            
            // Normalize to 0-360 range
            if angle < 0 {
                angle += 360
            }
            
            onDoubleTap?(angle)
        }
        
        override func draw(_ rect: CGRect) {
            guard let context = UIGraphicsGetCurrentContext() else { return }
            
            let center = CGPoint(x: bounds.midX, y: bounds.midY)
            let radius = min(bounds.width, bounds.height) / 2 - lineWidth / 2
            
            // Convert angles to radians
            let startRad = startAngle * .pi / 180
            let endRad = endAngle * .pi / 180
            
            // Clear context
            context.clear(rect)
            
            // Setup stroke
            context.setStrokeColor(color.cgColor)
            context.setLineWidth(lineWidth)
            
            // Draw arc
            context.addArc(
                center: center,
                radius: radius,
                startAngle: CGFloat(startRad),
                endAngle: CGFloat(endRad),
                clockwise: !clockwise // UIKit uses opposite convention
            )
            
            context.strokePath()
        }
    }
}

struct ArcStroke: View {
    var startAngle: Double
    var endAngle: Double
    var clockwise: Bool
    var lineWidth: CGFloat
    var color: Color
    var onDoubleTap: ((Double) -> Void)?  // Keep original signature
    
    var body: some View {
        GeometryReader { geometry in
            Arc(startAngle: .degrees(startAngle), endAngle: .degrees(endAngle), clockwise: clockwise)
                .stroke(color, lineWidth: lineWidth)
                .background(
                    Arc(startAngle: .degrees(startAngle), endAngle: .degrees(endAngle), clockwise: clockwise)
                        .stroke(Color.clear, lineWidth: lineWidth * 1.5)
                )
                .contentShape(
                    Arc(startAngle: .degrees(startAngle), endAngle: .degrees(endAngle), clockwise: clockwise)
                        .stroke(lineWidth: lineWidth * 1.5)
                )
                .gesture(
                    // Use TapGesture with count: 2 for double tap
                    TapGesture(count: 2)
                        .onEnded { _ in
                            // Use a more accurate method to detect tap location
                            // For now, we'll use the existing angle calculation in DonutChartView
                            let center = CGPoint(x: geometry.size.width / 2, y: geometry.size.height / 2)
                            
                            // Since we can't get the tap location directly with TapGesture,
                            // we'll use a point halfway between arcStartAngle and arcEndAngle
                            // This is for compatibility - not ideal but will compile
                            let midAngle = (startAngle + endAngle) / 2
                            
                            // Call the callback with the calculated angle
                            onDoubleTap?(midAngle)
                        }
                )
        }
    }
}

extension CGRect {
    var center: CGPoint {
        CGPoint(x: midX, y: midY)
    }
}

// Extension to convert SwiftUI Color to UIColor if needed
extension UIColor {
    convenience init(_ color: Color) {
        self.init(cgColor: color.cgColor ?? UIColor.gray.cgColor)
    }
}
