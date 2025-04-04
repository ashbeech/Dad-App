//
//  AddTaskView.swift
//  Dad App
//

import SwiftUI
import Combine

struct AddTaskView: View {
    @EnvironmentObject var dataStore: DataStore
    @Environment(\.presentationMode) var presentationMode
    
    let date: Date
    let initialTime: Date
    
    @State private var title: String = ""
    @State private var startTime: Date
    @State private var endTime: Date
    @State private var notes: String = ""
    @State private var showEndTime: Bool = false
    @State private var notifyOption: NotifyOption = .atTime
    @State private var customNotifyDays: Int = 0
    @State private var customNotifyHours: Int = 1
    @State private var completed: Bool = false
    @State private var titleModifiedByUser: Bool = false
    
    // For keyboard avoidance
    @State private var keyboardHeight: CGFloat = 0
    
    enum NotifyOption: String, CaseIterable, Identifiable {
        case atTime = "At the time"
        case oneHour = "1 hour before"
        case oneDay = "1 day before"
        case custom = "Custom time"
        
        var id: String { self.rawValue }
    }
    
    init(date: Date, initialTime: Date = Date()) {
        self.date = date
        self.initialTime = initialTime
        
        // Initialize with the provided initialTime
        _startTime = State(initialValue: initialTime)
        
        // Default end time is 1 hour after start time
        _endTime = State(initialValue: initialTime.addingTimeInterval(60 * 60))
    }
    
    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(spacing: 0) {
                    Form {
                        Section(header: Text("Task Details")) {
                            TextField("What needs to be completed?", text: $title)
                                .font(.body)
                                .foregroundColor(.primary)
                                .padding(.vertical, 4)
                                .overlay(
                                    VStack(alignment: .leading) {
                                        Text("Objective")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                            .padding(.leading, 4)
                                            .padding(.top, -25)
                                            .background(Color(.systemBackground))
                                        Spacer()
                                    }
                                        .padding(.horizontal, -8),
                                    alignment: .topLeading
                                )
                                .onChange(of: title) { _, _ in
                                    // Track that user has modified the title
                                    titleModifiedByUser = true
                                }
                        }
                        
                        Section(header: Text("Timing")) {
                            // Complete date and time picker for start time
                            DatePicker("Start Date & Time", selection: $startTime, displayedComponents: [.date, .hourAndMinute])
                                .onChange(of: startTime) { _, newValue in
                                    // When start time changes, update end time to be 1 hour later
                                    updateEndTimeToOneHourLater()
                                    
                                    // Validate time is within wake and bedtime
                                    let startDay = Calendar.current.startOfDay(for: newValue)
                                    let (validStart, _) = dataStore.validateEventTimes(startTime: newValue, endTime: endTime, for: startDay)
                                    if validStart != newValue {
                                        startTime = validStart
                                        // Update end time again if start time was adjusted
                                        updateEndTimeToOneHourLater()
                                    }
                                }
                            
                            Toggle("Add duration", isOn: $showEndTime)
                                .toggleStyle(SwitchToggleStyle(tint: .green))
                                .onChange(of: showEndTime) { _, newValue in
                                    if newValue {
                                        // When toggling duration on, ensure end time is 1 hour after start
                                        updateEndTimeToOneHourLater()
                                    }
                                }
                            
                            if showEndTime {
                                // Time-only picker for end time (always same day as start)
                                DatePicker("End Time", selection: $endTime, displayedComponents: .hourAndMinute)
                                    .onChange(of: endTime) { _, newValue in
                                        // Ensure end time stays on same day as start time
                                        ensureEndTimeOnSameDay()
                                        
                                        // Validate time is within wake and bedtime
                                        let startDay = Calendar.current.startOfDay(for: startTime)
                                        let (_, validEnd) = dataStore.validateEventTimes(startTime: startTime, endTime: endTime, for: startDay)
                                        if validEnd != newValue {
                                            endTime = validEnd
                                        }
                                    }
                            }
                        }
                        
                        Section(header: Text("Notification")) {
                            Picker("Notify Me", selection: $notifyOption) {
                                ForEach(NotifyOption.allCases) { option in
                                    Text(option.rawValue).tag(option)
                                }
                            }
                            
                            if notifyOption == .custom {
                                HStack {
                                    Stepper(value: $customNotifyDays, in: 0...7) {
                                        Text("\(customNotifyDays) \(customNotifyDays == 1 ? "day" : "days")")
                                    }
                                    Text("and")
                                    Stepper(value: $customNotifyHours, in: 0...23) {
                                        Text("\(customNotifyHours) \(customNotifyHours == 1 ? "hour" : "hours")")
                                    }
                                }
                                .padding(.top, 8)
                            }
                        }
                        
                        Section(header: Text("Notes")) {
                            ZStack(alignment: .topLeading) {
                                TextEditor(text: $notes)
                                    .frame(height: 100)
                                    .padding(.horizontal, -4)
                                
                                if notes.isEmpty {
                                    Text("Any special notes")
                                        .foregroundColor(.gray)
                                        .padding(.top, 8)
                                        .padding(.leading, 4)
                                }
                            }
                        }
                        
                        Button(action: saveTask) {
                            Text("Save Task")
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(title.isEmpty ? Color.gray : Color.green)
                                .foregroundColor(.white)
                                .cornerRadius(10)
                        }
                        .buttonStyle(PlainButtonStyle())
                        .padding()
                        .disabled(title.isEmpty)
                    }
                    .padding(.bottom, keyboardHeight) // Add padding to account for keyboard
                }
                .frame(minHeight: geometry.size.height)
            }
        }
        .onAppear {
            setupKeyboardObservers()
        }
        .onDisappear {
            removeKeyboardObservers()
        }
    }
    
    private func updateEndTimeToOneHourLater() {
        // Set end time to 1 hour after start time, keeping on same day
        let calendar = Calendar.current
        
        // Get date components from start time
        let startComponents = calendar.dateComponents([.year, .month, .day], from: startTime)
        
        // Create a date that's one hour later than start time
        let oneHourLater = startTime.addingTimeInterval(60 * 60)
        
        // Extract just the time components from the one-hour-later time
        let laterTimeComponents = calendar.dateComponents([.hour, .minute], from: oneHourLater)
        
        // Create new end time with start date + one hour later time
        var newEndComponents = startComponents
        newEndComponents.hour = laterTimeComponents.hour
        newEndComponents.minute = laterTimeComponents.minute
        
        if let newEndTime = calendar.date(from: newEndComponents) {
            self.endTime = newEndTime
        } else {
            // Fallback: just add one hour directly
            self.endTime = startTime.addingTimeInterval(60 * 60)
        }
    }
    
    private func ensureEndTimeOnSameDay() {
        // This function makes sure that when end time is changed,
        // it stays on the same calendar day as the start time
        let calendar = Calendar.current
        
        let startDay = calendar.startOfDay(for: startTime)
        let endDay = calendar.startOfDay(for: endTime)
        
        if startDay != endDay {
            // Extract just the time components from the current end time
            let endComponents = calendar.dateComponents([.hour, .minute], from: endTime)
            
            // Create a new date with the start date and the end time
            var newComponents = calendar.dateComponents([.year, .month, .day], from: startTime)
            newComponents.hour = endComponents.hour
            newComponents.minute = endComponents.minute
            
            if let newEndTime = calendar.date(from: newComponents) {
                // If the new end time would be before the start time, add 1 hour to start time
                if newEndTime <= startTime {
                    self.endTime = startTime.addingTimeInterval(60 * 60)
                } else {
                    self.endTime = newEndTime
                }
            }
        }
    }
    
    private func setupKeyboardObservers() {
        // Observe keyboard appearance and get height
        NotificationCenter.default.addObserver(
            forName: UIResponder.keyboardWillShowNotification,
            object: nil,
            queue: .main
        ) { notification in
            guard let keyboardFrame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect else { return }
            self.keyboardHeight = keyboardFrame.height
        }
        
        // Observe keyboard disappearance
        NotificationCenter.default.addObserver(
            forName: UIResponder.keyboardWillHideNotification,
            object: nil,
            queue: .main
        ) { _ in
            self.keyboardHeight = 0
        }
    }
    
    private func removeKeyboardObservers() {
        NotificationCenter.default.removeObserver(self)
    }
    
    private func saveTask() {
        // Default end time if not showing end time section
        let finalEndTime = showEndTime ? endTime : startTime.addingTimeInterval(1 * 60) // 1 minute duration for point events
        
        // Create a new task - past tense title will be automatically generated in the initializer
        let taskEvent = TaskEvent(
            date: startTime,
            title: title, // Store original title
            endTime: finalEndTime,
            notes: notes,
            isTemplate: false,
            completed: completed,
            isOngoing: false,
            hasEndTime: showEndTime // Property to track if this task has an end time
        )
        
        // Determine which date to use (the day of the start time)
        let calendar = Calendar.current
        let taskDate = calendar.startOfDay(for: startTime)
        
        // Add task to data store
        dataStore.addTaskEvent(taskEvent, for: taskDate)
        
        // Calculate notification time
        let notificationTime: Date
        switch notifyOption {
        case .atTime:
            notificationTime = startTime // Notify at the exact time
        case .oneHour:
            notificationTime = startTime.addingTimeInterval(-3600) // 1 hour before
        case .oneDay:
            notificationTime = startTime.addingTimeInterval(-86400) // 1 day before
        case .custom:
            let totalSeconds = (customNotifyDays * 24 * 60 * 60) + (customNotifyHours * 60 * 60)
            notificationTime = startTime.addingTimeInterval(-Double(totalSeconds))
        }
        
        // Schedule notification
        scheduleTaskNotification(taskEvent, at: notificationTime)
        
        presentationMode.wrappedValue.dismiss()
    }
    
    private func scheduleTaskNotification(_ task: TaskEvent, at time: Date) {
        // Only schedule if it's in the future
        if time > Date() {
            let content = UNMutableNotificationContent()
            content.title = "Reminder: \(task.title)"
            content.body = "Objective scheduled for \(formatTime(task.date))"
            if !task.notes.isEmpty {
                content.body += " - \(task.notes)"
            }
            content.sound = .default
            
            let triggerDate = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: time)
            let trigger = UNCalendarNotificationTrigger(dateMatching: triggerDate, repeats: false)
            
            let request = UNNotificationRequest(
                identifier: "task-\(task.id.uuidString)",
                content: content,
                trigger: trigger
            )
            
            UNUserNotificationCenter.current().add(request)
        }
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}
