//
//  DonutChartView.swift
//  Dad App
//
//  Created by Ashley Davison on 06/03/2025.
//

import SwiftUI
import UIKit // Added to access UIImpactFeedbackGenerator

struct DonutChartView: View {
    @EnvironmentObject var dataStore: DataStore
    let date: Date
    let events: [Event]
    @Binding var selectedEvent: Event?
    @Binding var filteredEventTypes: [EventType]?
    
    // Drag state
    @State private var currentActiveEvent: ActiveEvent? = nil
    @State private var timer: Timer? = nil
    @State private var isDragging: Bool = false
    @State private var draggedEventId: UUID? = nil
    @State private var dragTime: Date = Date()
    @State private var dragAngle: Double = 0
    @State private var showConfirmationTime: Bool = false
    @State private var dragMode: DragMode = .wholeSleep
    @State private var dragEndTime: Date = Date()
    @State private var dragEndAngle: Double = 0
    @State private var originalStartTime: Date = Date()
    @State private var originalEndTime: Date = Date()
    @State private var refreshTrigger: Bool = false
    @State private var lastWakeTime: Date = Date()
    @State private var lastBedTime: Date = Date()
    
    @State private var currentTimeAngle: Double = 0
    @State private var animateCurrentTimeLine: Bool = false
    @State private var timerUpdateCounter: Int = 0
    
        
    // Enum to track what part of sleep event is being dragged
    private enum DragMode {
        case startPoint
        case endPoint
        case wholeSleep
    }
    
    init(date: Date, events: [Event], selectedEvent: Binding<Event?>, filteredEventTypes: Binding<[EventType]?>) {
        self.date = date
        self.events = events
        self._selectedEvent = selectedEvent
        self._filteredEventTypes = filteredEventTypes
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Draw the arc representing wake hours
                ArcStroke(
                    startAngle: arcStartAngle,
                    endAngle: arcEndAngle,
                    clockwise: false,
                    lineWidth: donutWidth,
                    color: Color.gray.opacity(0.7)
                )
                
                // Draw sleep events as capsules first (so they're below other elements)
                sleepEventsView(geometry: geometry)
                
                // Draw feed events as circles
                feedEventsView(geometry: geometry)
                
                // Draw wake and bedtime circles
                specialEventsView(geometry: geometry)
                
                // Draw the current time marker if within waking hours AND it's today
                currentTimeMarkerView(geometry: geometry)
                    .zIndex(100)
                
                // Optional: Add time markers for better readability
                timeMarkersView(geometry: geometry)
                
                // Time label during drag
                dragTimeLabelsView(geometry: geometry)
                
                // Confirmation time label after drop
                confirmationTimeLabelsView(geometry: geometry)
                
                // Hidden element that forces view to update when refreshTrigger changes
                Color.clear
                    .frame(width: 0, height: 0)
                    .onReceive(dataStore.$baby) { newBaby in
                        // Only trigger refresh if wake or bedtime has changed
                        if newBaby.wakeTime != lastWakeTime || newBaby.bedTime != lastBedTime {
                            withAnimation(.easeInOut(duration: 0.5)) {
                                // Update tracking values
                                lastWakeTime = newBaby.wakeTime
                                lastBedTime = newBaby.bedTime
                                
                                // Force view to update
                                refreshTrigger.toggle()
                            }
                        }
                    }
            }.onAppear {
                // Set initial values for time tracking
                lastWakeTime = dataStore.baby.wakeTime
                lastBedTime = dataStore.baby.bedTime
                
                // Listen for notifications to clear active nap
                NotificationCenter.default.addObserver(
                    forName: NSNotification.Name("ClearActiveNap"),
                    object: nil,
                    queue: .main
                ) { notification in
                    if let eventId = notification.object as? UUID,
                       currentActiveEvent?.id == eventId {
                        currentActiveEvent = nil
                    }
                }
                
                // Check for any ongoing naps and set as active event
                checkForOngoingNaps()
                
                // Setup the enhanced timer
                enhancedTimerSetup()
                
                // Start with the correct current time
                if Calendar.current.isDateInToday(date), let currentTime = getCurrentTimeForToday() {
                    currentTimeAngle = angleForTime(currentTime)
                }
            }
            .onDisappear {
                // Remove observer when view disappears
                NotificationCenter.default.removeObserver(self)
                timer?.invalidate()
                timer = nil
            }
            .id(refreshTrigger)
        }
        .aspectRatio(1, contentMode: .fit)
        .padding()
    }
    
    private let donutWidth: CGFloat = 50
    private let arcStartAngle: Double = 110
    private let arcEndAngle: Double = 70

    private func calculateTotalWakingHours() -> Double {
        let calendar = Calendar.current
        let wakeComponents = calendar.dateComponents([.hour, .minute], from: dataStore.baby.wakeTime)
        let bedComponents = calendar.dateComponents([.hour, .minute], from: dataStore.baby.bedTime)
        
        guard let wakeHour = wakeComponents.hour, let wakeMinute = wakeComponents.minute,
              let bedHour = bedComponents.hour, let bedMinute = bedComponents.minute else {
            return 14.0 // Default to 14 hours if we can't calculate
        }
        
        let wakeTimeMinutes = Double(wakeHour * 60 + wakeMinute)
        let bedTimeMinutes = Double(bedHour * 60 + bedMinute)
        
        // Handle case where bedtime is after midnight
        let totalWakingMinutes = bedTimeMinutes > wakeTimeMinutes
            ? bedTimeMinutes - wakeTimeMinutes
            : (24 * 60 - wakeTimeMinutes) + bedTimeMinutes
        
        return totalWakingMinutes / 60.0 // Convert minutes to hours
    }
    
    // MARK: - Component Views
    
    private func sleepEventView(event: Event, geometry: GeometryProxy) -> some View {
        Group {
            if let sleepEvent = getSleepEventForDate(event) {
                let isEventInvolved = draggedEventId == event.id
                
                // Calculate display times based on drag state and ongoing status
                let displayStartTime: Date = {
                    if isEventInvolved {
                        switch dragMode {
                        case .startPoint:
                            return dragTime
                        case .endPoint:
                            return sleepEvent.date
                        case .wholeSleep:
                            return dragTime
                        }
                    } else {
                        return sleepEvent.date
                    }
                }()
                
                let displayEndTime: Date = {
                    if isEventInvolved {
                        switch dragMode {
                        case .startPoint:
                            return sleepEvent.endTime
                        case .endPoint:
                            return dragEndTime
                        case .wholeSleep:
                            return dragEndTime
                        }
                    } else if sleepEvent.isOngoing && !sleepEvent.isPaused && Calendar.current.isDateInToday(date) {
                        // For ongoing naps that aren't paused, use the current time as the "end" time
                        // but only if it's less than the scheduled end time
                        return min(Date(), sleepEvent.endTime)
                    } else {
                        return sleepEvent.endTime
                    }
                }()
                
                // Now create the actual view elements
                Group {
                    // The main capsule body
                    SleepArcCapsule(
                        startAngle: angleForTime(displayStartTime),
                        endAngle: angleForTime(displayEndTime),
                        donutWidth: donutWidth * 0.8,
                        color: colorForEvent(event),
                        isOngoing: sleepEvent.isOngoing && !sleepEvent.isPaused && Calendar.current.isDateInToday(date)
                    )
                    .shadow(radius: isEventInvolved ? 4 : 0)
                    
                    // Start circle (must be same size as feed events)
                    Circle()
                        .fill(colorForEvent(event))
                        .frame(width: donutWidth * 0.8, height: donutWidth * 0.8)
                        .position(pointOnDonutCenter(angle: angleForTime(displayStartTime), geometry: geometry))
                    
                    // End circle (must be same size as feed events)
                    // Add pulsing effect for ongoing events
                    if sleepEvent.isOngoing && !sleepEvent.isPaused && Calendar.current.isDateInToday(date) {
                        PulsingCircle(
                            color: colorForEvent(event),
                            size: donutWidth * 0.8
                        )
                        .position(pointOnDonutCenter(angle: angleForTime(displayEndTime), geometry: geometry))
                    } else {
                        Circle()
                            .fill(colorForEvent(event))
                            .frame(width: donutWidth * 0.8, height: donutWidth * 0.8)
                            .position(pointOnDonutCenter(angle: angleForTime(displayEndTime), geometry: geometry))
                    }
                }
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            // Store the event's original state when drag begins
                            if !isDragging {
                                // Use new method to save to undo stack
                                dataStore.saveCurrentStateForUndo(eventId: event.id, for: date)
                            }
                            
                            handleSleepEventDragChange(value: value, event: event, sleepEvent: sleepEvent, geometry: geometry)
                        }
                        .onEnded { value in
                            handleSleepEventDragEnd(value: value, event: event)
                        }
                )
                .onTapGesture {
                    if !isDragging {
                        // For ongoing naps, toggle the active state
                        if let sleepEvent = getSleepEventForDate(event),
                           sleepEvent.isOngoing && sleepEvent.sleepType == .nap {
                            
                            // If this is already the active event, clear it
                            if let activeEvent = currentActiveEvent, activeEvent.id == event.id {
                                currentActiveEvent = nil
                            } else {
                                // Otherwise, set it as the active event
                                currentActiveEvent = ActiveEvent.from(sleepEvent: sleepEvent)
                            }
                        } else {
                            // For non-ongoing events, just select them
                            selectedEvent = event
                        }
                    }
                }
            }
        }
    }

    func enhancedTimerSetup() {
        // Start a more frequent timer (every 0.5 seconds) to update ongoing events
        timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { _ in
            // Calculate the current time angle for today's date
            if Calendar.current.isDateInToday(date) {
                if let currentTime = getCurrentTimeForToday() {
                    withAnimation(.linear(duration: 0.5)) {
                        currentTimeAngle = angleForTime(currentTime)
                    }
                }
            }
            
            // Update the counter to force a view refresh
            timerUpdateCounter += 1
            
            // Check for ongoing naps to keep the active event updated
            checkForOngoingNaps()
        }
    }
    
    private func validateSleepEventTimes(startTime: Date, endTime: Date) -> (Date, Date) {
        let validStartTime = startTime
        var validEndTime = endTime
        
        // 1. Ensure end time is not before start time
        if validEndTime <= validStartTime {
            validEndTime = validStartTime.addingTimeInterval(15 * 60) // 15 min after start
        }
        
        // 2. Ensure duration is not more than 12 hours
        let maxDuration: TimeInterval = 12 * 3600 // 12 hours in seconds
        let duration = validEndTime.timeIntervalSince(validStartTime)
        
        if duration > maxDuration {
            // If over 12 hours, cap to 12 hours from start
            validEndTime = validStartTime.addingTimeInterval(maxDuration)
        }
        
        // 3. Ensure they are on the same day
        let calendar = Calendar.current
        let startDay = calendar.dateComponents([.year, .month, .day], from: validStartTime)
        let endDay = calendar.dateComponents([.year, .month, .day], from: validEndTime)
        
        if startDay.day != endDay.day ||
           startDay.month != endDay.month ||
           startDay.year != endDay.year {
            // If on different days, cap to 11:59 PM of start day
            var endComponents = calendar.dateComponents([.year, .month, .day], from: validStartTime)
            endComponents.hour = 23
            endComponents.minute = 59
            validEndTime = calendar.date(from: endComponents) ?? validEndTime
        }
        
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
        let isEventInvolved = draggedEventId == event.id
        
        // Choose which time/angle to use for positioning
        let displayTime = (isEventInvolved) ? dragTime : event.date
        let angle = angleForTime(displayTime)
        
        // Draw the event circle
        return Circle()
            .fill(colorForEvent(event))
            .frame(width: donutWidth * 0.8, height: donutWidth * 0.8)
            .scaleEffect(isDragging && isEventInvolved ? 1.2 : 1.0)
            .shadow(radius: isDragging && isEventInvolved ? 4 : 0)
            .position(pointOnDonutCenter(angle: angle, geometry: geometry))
            .gesture(
                DragGesture()
                    .onChanged { value in
                        // Store the event's original state when drag begins
                        if !isDragging, let _ = dataStore.getFeedEvent(id: event.id, for: date) {
                            // Use new method to save to undo stack
                            dataStore.saveCurrentStateForUndo(eventId: event.id, for: date)
                        }
                        
                        handleFeedEventDragChange(value: value, event: event, geometry: geometry)
                    }
                    .onEnded { value in
                        handleFeedEventDragEnd(value: value, event: event)
                    }
            )
            .onTapGesture {
                if !isDragging {
                    selectedEvent = event
                }
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
                .zIndex(-1) // Set to negative z-index to ensure it stays below other elements
                .onTapGesture {
                    if !isDragging {
                        if let event = wakeEvent {
                            selectedEvent = event.toEvent()
                        } else {
                            createDefaultWakeEvent()
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
                .zIndex(-1) // Set to negative z-index to ensure it stays below other elements
                .onTapGesture {
                    if !isDragging {
                        if let event = bedtimeEvent {
                            selectedEvent = event.toEvent()
                        } else {
                            createDefaultBedtimeEvent()
                        }
                    }
                }
                        }
        .id("specialEvents-\(refreshTrigger)")
    }
    
    private func currentTimeMarkerView(geometry: GeometryProxy) -> some View {
        Group {
            if Calendar.current.isDateInToday(date) {
                let angleRadians = currentTimeAngle * .pi / 180
                
                // Calculate the center point
                let center = CGPoint(x: geometry.size.width / 2, y: geometry.size.height / 2)
                let radius = min(geometry.size.width, geometry.size.height) / 2
                
                // Calculate the inner and outer points for the line
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
                
                // Draw a line instead of a circle
                Path { path in
                    path.move(to: innerPoint)
                    path.addLine(to: outerPoint)
                }
                .stroke(Color.red, lineWidth: 3)
                .shadow(color: Color.red.opacity(0.4), radius: 2, x: 0, y: 0)
                .zIndex(100) // Ensure it's always on top
            }
        }.id("timeMarker-\(refreshTrigger)")
    }
    
    private func sleepEventsView(geometry: GeometryProxy) -> some View {
        Group {
            // This invisible view ensures updates happen based on the timer
            Color.clear
                .frame(width: 0, height: 0)
                .onChange(of: timerUpdateCounter) { _, _ in }
            
            // Show the NowFocusView for any active events
            if let activeEvent = currentActiveEvent, activeEvent.type == .sleep {
                NowFocusView(currentActiveEvent: $currentActiveEvent, date: date)
                    .frame(width: geometry.size.width * 0.5, height: geometry.size.height * 0.5)
                    .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
                    .zIndex(100) // Ensure it's on top of everything
            }
            
            ForEach(events.filter { event in
                // Only include sleep events that aren't wake/bedtime AND match the filter if active
                if event.type == .sleep,
                   let date = Calendar.current.date(from: Calendar.current.dateComponents([.year, .month, .day], from: event.date)),
                   let sleepEvent = dataStore.getSleepEvent(id: event.id, for: date),
                   sleepEvent.sleepType == .nap {
                    return filteredEventTypes?.contains(.sleep) ?? true || filteredEventTypes == nil
                }
                return false
            }) { event in
                sleepEventView(event: event, geometry: geometry)
            }
        }
        .id("sleepEvents-\(refreshTrigger)")
    }
    
    private func timeMarkersView(geometry: GeometryProxy) -> some View {
        let calendar = Calendar.current
        let wakeComponents = calendar.dateComponents([.hour, .minute], from: dataStore.baby.wakeTime)
        let bedComponents = calendar.dateComponents([.hour, .minute], from: dataStore.baby.bedTime)

        guard let wakeHour = wakeComponents.hour, let wakeMinute = wakeComponents.minute,
              let bedHour = bedComponents.hour, let bedMinute = bedComponents.minute else {
            // Return an empty Group to match the return type
            return Group { EmptyView() }
        }

        let wakeTimeHour = Double(wakeHour) + (Double(wakeMinute) / 60.0)
        let bedTimeHour = Double(bedHour) + (Double(bedMinute) / 60.0)

        // Adjust for cases where bedtime is after midnight
        let adjustedBedTimeHour = bedTimeHour < wakeTimeHour ? bedTimeHour + 24.0 : bedTimeHour

        // Calculate total waking hours
        let totalWakingHours = adjustedBedTimeHour - wakeTimeHour

        // Generate appropriate time markers based on waking hours
        let markers = generateTimeMarkers(wakeHour: wakeTimeHour, totalWakingHours: totalWakingHours)

        // Return a Group containing the ForEach
        return Group {
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
        
        while currentHour < endHour {
            markers.append(currentHour)
            currentHour += spacing
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
            if isDragging, draggedEventId != nil {
                Group {
                    switch dragMode {
                    case .startPoint:
                        Text(formatTime(dragTime))
                            .font(.caption)
                            .foregroundColor(.white)
                            .padding(4)
                            .background(Color.black.opacity(0.7))
                            .cornerRadius(4)
                            .position(pointOutsideDonut(angle: dragAngle, geometry: geometry, offset: -35))
                    case .endPoint:
                        Text(formatTime(dragEndTime))
                            .font(.caption)
                            .foregroundColor(.white)
                            .padding(4)
                            .background(Color.black.opacity(0.7))
                            .cornerRadius(4)
                            .position(pointOutsideDonut(angle: dragEndAngle, geometry: geometry, offset: -35))
                    case .wholeSleep:
                        if let event = events.first(where: { $0.id == draggedEventId }),
                           event.type == .sleep {
                            // For sleep events, show both times
                            VStack(spacing: 2) {
                                Text(formatTime(dragTime))
                                Text("-")
                                Text(formatTime(dragEndTime))
                            }
                            .font(.caption)
                            .foregroundColor(.white)
                            .padding(4)
                            .background(Color.black.opacity(0.7))
                            .cornerRadius(4)
                            .position(pointOutsideDonut(angle: (dragAngle + dragEndAngle) / 2, geometry: geometry, offset: -50))
                        } else {
                            // For feed events, show just one time
                            Text(formatTime(dragTime))
                                .font(.caption)
                                .foregroundColor(.white)
                                .padding(4)
                                .background(Color.black.opacity(0.7))
                                .cornerRadius(4)
                                .position(pointOutsideDonut(angle: dragAngle, geometry: geometry, offset: -35))
                        }
                    }
                }
            }
        }
    }
    
    private func confirmationTimeLabelsView(geometry: GeometryProxy) -> some View {
        Group {
            if showConfirmationTime, !isDragging, draggedEventId != nil {
                Group {
                    if let event = events.first(where: { $0.id == draggedEventId }),
                       event.type == .sleep {
                        // For sleep events, show appropriate confirmation
                        switch dragMode {
                        case .startPoint:
                            Text(formatTime(dragTime))
                                .font(.caption)
                                .foregroundColor(.white)
                                .padding(4)
                                .background(Color.green.opacity(0.9))
                                .cornerRadius(4)
                                .position(pointOutsideDonut(angle: dragAngle, geometry: geometry, offset: -35))
                                .transition(.opacity)
                        case .endPoint:
                            Text(formatTime(dragEndTime))
                                .font(.caption)
                                .foregroundColor(.white)
                                .padding(4)
                                .background(Color.green.opacity(0.9))
                                .cornerRadius(4)
                                .position(pointOutsideDonut(angle: dragEndAngle, geometry: geometry, offset: -35))
                                .transition(.opacity)
                        case .wholeSleep:
                            // Show confirmation in middle for whole sleep drag
                            VStack(spacing: 2) {
                                Text(formatTime(dragTime))
                                Text("-")
                                Text(formatTime(dragEndTime))
                            }
                            .font(.caption)
                            .foregroundColor(.white)
                            .padding(4)
                            .background(Color.green.opacity(0.9))
                            .cornerRadius(4)
                            .position(pointOutsideDonut(angle: (dragAngle + dragEndAngle) / 2, geometry: geometry, offset: -50))
                            .transition(.opacity)
                        }
                    } else {
                        // For feed events, simple confirmation
                        Text(formatTime(dragTime))
                            .font(.caption)
                            .foregroundColor(.white)
                            .padding(4)
                            .background(Color.green.opacity(0.9))
                            .cornerRadius(4)
                            .position(pointOutsideDonut(angle: dragAngle, geometry: geometry, offset: -35))
                            .transition(.opacity)
                    }
                }
            }
        }
    }
    
    // MARK: - Drag Handling
    
    private func handleSleepEventDragChange(value: DragGesture.Value, event: Event, sleepEvent: SleepEvent, geometry: GeometryProxy) {
        // First drag begins - determine drag mode
        if !isDragging {
            // Store original times for whole sleep dragging
            originalStartTime = sleepEvent.date
            originalEndTime = sleepEvent.endTime
            
            // Calculate angles
            let startAngle = angleForTime(sleepEvent.date)
            let endAngle = angleForTime(sleepEvent.endTime)
            let tapAngle = angleFromPoint(value.startLocation, geometry: geometry)
            
            // Calculate distance from tap to start and end points
            let startDiff = angleDifference(tapAngle, startAngle)
            let endDiff = angleDifference(tapAngle, endAngle)
            
            // Determine drag mode based on proximity to start/end points
            if startDiff < 10 { // Within 10 degrees of start
                dragMode = .startPoint
            } else if endDiff < 10 { // Within 10 degrees of end
                dragMode = .endPoint
            } else {
                // Otherwise, drag the whole sleep event
                dragMode = .wholeSleep
            }
        }
        
        // Calculate new angle from the drag position
        let newAngle = angleFromPoint(value.location, geometry: geometry)
        let constrainedAngle = constrainAngleToArc(newAngle)
        let newTime = timeFromAngle(constrainedAngle)
        
        // Get wake and bedtime events for constraints
        let wakeEvent = findWakeEvent()
        let bedtimeEvent = findBedtimeEvent()
        let wakeTime = wakeEvent?.date ?? dataStore.baby.wakeTime
        let bedTime = bedtimeEvent?.date ?? dataStore.baby.bedTime
        
        // Update UI state based on drag mode
        withAnimation(nil) {
            isDragging = true
            draggedEventId = event.id
            showConfirmationTime = false
            
            switch dragMode {
            case .startPoint:
                // Ensure start time is not after end time
                if newTime >= sleepEvent.endTime {
                    dragTime = sleepEvent.endTime.addingTimeInterval(-15 * 60) // 15 min before end time
                    dragAngle = angleForTime(dragTime)
                } else if newTime < wakeTime {
                    // Don't allow dragging before wake time
                    dragTime = wakeTime
                    dragAngle = angleForTime(wakeTime)
                } else {
                    dragAngle = constrainedAngle
                    dragTime = newTime
                }
                
            case .endPoint:
                // Ensure end time is not before start time
                if newTime <= sleepEvent.date {
                    dragEndTime = sleepEvent.date.addingTimeInterval(15 * 60) // 15 min after start time
                    dragEndAngle = angleForTime(dragEndTime)
                } else if newTime > bedTime {
                    // Don't allow dragging after bedtime
                    dragEndTime = bedTime
                    dragEndAngle = angleForTime(bedTime)
                } else {
                    dragEndAngle = constrainedAngle
                    dragEndTime = newTime
                }
                
            case .wholeSleep:
                // Calculate the original duration
                let duration = originalEndTime.timeIntervalSince(originalStartTime)
                
                // Don't allow dragging beyond the wake/bedtime constraints
                if newTime < wakeTime {
                    // If start would be before wake time, constrain to wake time
                    dragTime = wakeTime
                    dragAngle = angleForTime(dragTime)
                    dragEndTime = dragTime.addingTimeInterval(duration)
                    dragEndAngle = angleForTime(dragEndTime)
                } else if newTime.addingTimeInterval(duration) > bedTime {
                    // If end would be after bedtime, constrain to have end at bedtime
                    dragEndTime = bedTime
                    dragEndAngle = angleForTime(dragEndTime)
                    dragTime = dragEndTime.addingTimeInterval(-duration)
                    dragAngle = angleForTime(dragTime)
                } else {
                    // Normal case - in bounds
                    dragAngle = constrainedAngle
                    dragTime = newTime
                    dragEndTime = dragTime.addingTimeInterval(duration)
                    dragEndAngle = angleForTime(dragEndTime)
                }
                
                // Apply additional validation constraints
                (dragTime, dragEndTime) = validateSleepEventTimes(startTime: dragTime, endTime: dragEndTime)
                dragAngle = angleForTime(dragTime)
                dragEndAngle = angleForTime(dragEndTime)
            }
        }
    }
    
    private func handleSleepEventDragEnd(value: DragGesture.Value, event: Event) {
        // Update the data model based on drag mode
        switch dragMode {
        case .startPoint:
            updateSleepEventStartTime(event, to: dragTime)
        case .endPoint:
            updateSleepEventEndTime(event, to: dragEndTime)
        case .wholeSleep:
            updateSleepEventWhole(event, startTime: dragTime, endTime: dragEndTime)
        }
        
        // Show confirmation
        withAnimation(.easeOut(duration: 0.2)) {
            isDragging = false
            showConfirmationTime = true
        }
        
        // Keep draggedEventId until confirmation is hidden
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            withAnimation(.easeOut(duration: 0.2)) {
                showConfirmationTime = false
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                if draggedEventId == event.id {
                    draggedEventId = nil
                }
            }
        }
    }
    
    private func handleFeedEventDragChange(value: DragGesture.Value, event: Event, geometry: GeometryProxy) {
        // Store the event's original state when drag begins
        if !isDragging, let _ = dataStore.getFeedEvent(id: event.id, for: date) {
            // Use new method to save to undo stack
            dataStore.saveCurrentStateForUndo(eventId: event.id, for: date)
        }
        
        // Calculate new angle from the drag position
        let newAngle = angleFromPoint(value.location, geometry: geometry)
        let constrainedAngle = constrainAngleToArc(newAngle)
        let newTime = timeFromAngle(constrainedAngle)
        
        // Update UI state
        withAnimation(nil) { // No animation during drag movement
            isDragging = true
            draggedEventId = event.id
            dragMode = .wholeSleep // Default mode for feed events
            dragAngle = constrainedAngle
            dragTime = newTime
            showConfirmationTime = false
        }
    }
    
    private func handleFeedEventDragEnd(value: DragGesture.Value, event: Event) {
        // Update the data model
        updateEventTime(event, to: dragTime)
        
        // Show confirmation with the same time
        withAnimation(.easeOut(duration: 0.2)) {
            isDragging = false
            showConfirmationTime = true
        }
        
        // Keep draggedEventId and dragTime until confirmation is hidden
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            withAnimation(.easeOut(duration: 0.2)) {
                showConfirmationTime = false
            }
            
            // Only reset the dragged event ID after confirmation disappears
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                if draggedEventId == event.id {
                    draggedEventId = nil
                }
            }
        }
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
    
    private func formatTime(_ time: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: time)
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
        
        // Use constrained angle to ensure the point stays on the arc
        let constrainedAngle = constrainAngleToArc(angle)
        let angleRadians = constrainedAngle * .pi / 180
        
        let x = center.x + radius * cos(angleRadians)
        let y = center.y + radius * sin(angleRadians)
        
        return CGPoint(x: x, y: y)
    }
    
    // Helper method for getting a point outside the donut for labels
    private func pointOutsideDonut(angle: Double, geometry: GeometryProxy, offset: CGFloat) -> CGPoint {
        let center = CGPoint(x: geometry.size.width / 2, y: geometry.size.height / 2)
        // Calculate radius to the outside of the donut plus offset
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
        let wakeComponents = calendar.dateComponents([.hour, .minute], from: dataStore.baby.wakeTime)
        let bedComponents = calendar.dateComponents([.hour, .minute], from: dataStore.baby.bedTime)
        
        guard let wakeHour = wakeComponents.hour, let wakeMinute = wakeComponents.minute,
              let bedHour = bedComponents.hour, let bedMinute = bedComponents.minute else {
            return Date() // Default if can't calculate
        }
        
        let wakeTimeMinutes = wakeHour * 60 + wakeMinute
        let bedTimeMinutes = bedHour * 60 + bedMinute
        
        // Handle case where bedtime is after midnight
        let totalWakingMinutes = bedTimeMinutes > wakeTimeMinutes
            ? bedTimeMinutes - wakeTimeMinutes
            : (24 * 60 - wakeTimeMinutes) + bedTimeMinutes
        
        // Calculate the total angle sweep of the arc
        let totalAngleSweep = (arcEndAngle - arcStartAngle + 360).truncatingRemainder(dividingBy: 360)
        
        // Normalize the input angle relative to the arc's start angle
        var relativeAngle = (angle - arcStartAngle + 360).truncatingRemainder(dividingBy: 360)
        if relativeAngle > totalAngleSweep {
            relativeAngle = totalAngleSweep // Cap at the arc's end
        }
        
        // Convert angle to normalized time position (0-1)
        let normalizedTime = relativeAngle / totalAngleSweep
        
        // Convert normalized time to minutes since wake time
        let minutesSinceWake = Int(normalizedTime * Double(totalWakingMinutes))
        
        // Create a new date with the date part from the input date and time from calculation
        var dateComponents = calendar.dateComponents([.year, .month, .day], from: date)
        
        let totalMinutes = wakeTimeMinutes + minutesSinceWake
        let hours = (totalMinutes / 60) % 24
        let minutes = totalMinutes % 60
        
        dateComponents.hour = hours
        dateComponents.minute = minutes
        
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
        let wakeComponents = calendar.dateComponents([.hour, .minute], from: dataStore.baby.wakeTime)
        let bedComponents = calendar.dateComponents([.hour, .minute], from: dataStore.baby.bedTime)
        
        guard let wakeHour = wakeComponents.hour, let wakeMinute = wakeComponents.minute,
              let bedHour = bedComponents.hour, let bedMinute = bedComponents.minute else {
            return arcStartAngle // Default if can't calculate
        }
        
        let wakeTimeMinutes = wakeHour * 60 + wakeMinute
        let bedTimeMinutes = bedHour * 60 + bedMinute
        
        // Handle case where bedtime is after midnight
        let totalWakingMinutes = bedTimeMinutes > wakeTimeMinutes
            ? bedTimeMinutes - wakeTimeMinutes
            : (24 * 60 - wakeTimeMinutes) + bedTimeMinutes
        
        let hourMinute = calendar.dateComponents([.hour, .minute], from: time)
        guard let hour = hourMinute.hour, let minute = hourMinute.minute else {
            return arcStartAngle
        }
        
        let timeMinutes = hour * 60 + minute
        
        // Calculate minutes since wake time, handling wrap-around at midnight if needed
        let minutesSinceWake = timeMinutes >= wakeTimeMinutes
            ? timeMinutes - wakeTimeMinutes
            : (24 * 60 - wakeTimeMinutes) + timeMinutes
        
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
            break // Handle task events if needed
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
    
    // Add this new method to check for ongoing naps
    private func checkForOngoingNaps() {
        // Only check for today
        if Calendar.current.isDateInToday(date) {
            // Get all ongoing sleep events for today
            let ongoingNaps = dataStore.getOngoingSleepEvents(for: date).filter { $0.sleepType == .nap }
            
            // If there's an ongoing nap, set it as the active event
            if let ongoingNap = ongoingNaps.first {
                currentActiveEvent = ActiveEvent.from(sleepEvent: ongoingNap)
                
                // Log for debugging
                print("Found ongoing nap: \(ongoingNap.id)")
            } else {
                // Clear any existing active event if there are no ongoing naps
                if currentActiveEvent != nil {
                    currentActiveEvent = nil
                }
            }
        }
    }
}

struct PulsingCircle: View {
    var color: Color
    var size: CGFloat
    
    @State private var isAnimating = false
    
    var body: some View {
        ZStack {
            // Main circle
            Circle()
                .fill(color)
                .frame(width: size, height: size)
            
            // Pulsing circle
            Circle()
                .stroke(color, lineWidth: 2)
                .frame(width: size * (isAnimating ? 1.3 : 1.0),
                       height: size * (isAnimating ? 1.3 : 1.0))
                .opacity(isAnimating ? 0 : 0.7)
        }
        .onAppear {
            withAnimation(Animation.easeInOut(duration: 1.2).repeatForever(autoreverses: false)) {
                isAnimating = true
            }
        }
    }
}

struct SleepArcCapsule: View {
    var startAngle: Double
    var endAngle: Double
    var donutWidth: CGFloat
    var color: Color
    var isOngoing: Bool = false
    
    var body: some View {
        GeometryReader { geometry in
            Path { path in
                let center = CGPoint(x: geometry.size.width / 2, y: geometry.size.height / 2)
                let radius = min(geometry.size.width, geometry.size.height) / 2
                
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
                    let _ = center.x + outerRadius * cos(endRad)  // endOuterX - replaced with _
                    let _ = center.y + outerRadius * sin(endRad)  // endOuterY - replaced with _
                    
                    let _ = center.x + innerRadius * cos(startRad) // startInnerX - replaced with _
                    let _ = center.y + innerRadius * sin(startRad) // startInnerY - replaced with _
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
            }
            .fill(color)
            // Add subtle animation for ongoing events
            .overlay(
                Group {
                    if isOngoing {
                        LinearGradient(
                            gradient: Gradient(colors: [color.opacity(0.5), color]),
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                        .mask(
                            Rectangle()
                                .fill(Color.white)
                                .frame(width: geometry.size.width, height: geometry.size.height)
                        )
                        .opacity(0.3)
                    }
                }
            )
        }
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

// A stroke style for the arc with customizable width
struct ArcStroke: View {
    var startAngle: Double
    var endAngle: Double
    var clockwise: Bool
    var lineWidth: CGFloat
    var color: Color
    
    var body: some View {
        Arc(startAngle: .degrees(startAngle), endAngle: .degrees(endAngle), clockwise: clockwise)
            .stroke(color, lineWidth: lineWidth)
    }
}
