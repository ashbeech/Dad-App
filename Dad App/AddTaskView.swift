//
//  AddTaskView.swift
//  Dad App
//

import SwiftUI

struct AddTaskView: View {
    @EnvironmentObject var dataStore: DataStore
    @Environment(\.presentationMode) var presentationMode
    
    let date: Date
    let initialTime: Date
    
    @State private var title: String = ""
    @State private var priority: TaskPriority = .medium
    @State private var startTime: Date
    @State private var endTime: Date
    @State private var notes: String = ""
    @State private var isTemplate: Bool = false
    @State private var notifyOption: NotifyOption = .oneHour
    @State private var customNotifyDays: Int = 0
    @State private var customNotifyHours: Int = 1
    
    enum NotifyOption: String, CaseIterable, Identifiable {
        case oneHour = "1 hour before"
        case oneDay = "1 day before"
        case custom = "Custom time"
        
        var id: String { self.rawValue }
    }
    
    init(date: Date, initialTime: Date = Date()) {
        self.date = date
        self.initialTime = initialTime
        
        // Initialize with the provided initialTime instead of just the date
        let calendar = Calendar.current
        
        // Extract year, month, day from date and hour, minute from initialTime
        var dateComponents = calendar.dateComponents([.year, .month, .day], from: date)
        let timeComponents = calendar.dateComponents([.hour, .minute], from: initialTime)
        
        // Combine them
        dateComponents.hour = timeComponents.hour
        dateComponents.minute = timeComponents.minute
        
        let combinedDate = calendar.date(from: dateComponents) ?? initialTime
        _startTime = State(initialValue: combinedDate)
        
        // Default end time is 30 mins after start time
        _endTime = State(initialValue: combinedDate.addingTimeInterval(30 * 60))
    }
    
    var body: some View {
        Form {
            Section(header: Text("Task Details")) {
                TextField("Task Title", text: $title)
                
                Picker("Priority", selection: $priority) {
                    ForEach(TaskPriority.allCases, id: \.self) { priority in
                        HStack {
                            Circle()
                                .fill(priority.color)
                                .frame(width: 12, height: 12)
                            Text(priority.rawValue)
                        }
                        .tag(priority)
                    }
                }
            }
            
            Section(header: Text("Timing")) {
                DatePicker("Start Time", selection: $startTime, displayedComponents: .hourAndMinute)
                    .onChange(of: startTime) { _, newValue in
                        // Validate time is within wake and bedtime
                        let (validStart, _) = dataStore.validateEventTimes(startTime: newValue, endTime: endTime, for: date)
                        if validStart != newValue {
                            startTime = validStart
                        }
                        
                        // Ensure end time is after start time
                        if endTime <= validStart {
                            endTime = validStart.addingTimeInterval(30 * 60)
                        }
                    }
                
                DatePicker("End Time", selection: $endTime, displayedComponents: .hourAndMinute)
                    .onChange(of: endTime) { _, newValue in
                        // Validate time is within wake and bedtime
                        let (_, validEnd) = dataStore.validateEventTimes(startTime: startTime, endTime: newValue, for: date)
                        if validEnd != newValue {
                            endTime = validEnd
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
                TextField("Any special notes", text: $notes)
            }
            
            Section {
                Toggle("Save as template", isOn: $isTemplate)
                    .toggleStyle(SwitchToggleStyle(tint: .blue))
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
    }
    
    private func saveTask() {
        // Create a new task
        let taskEvent = TaskEvent(
            date: startTime,
            title: title,
            endTime: endTime,
            notes: notes,
            isTemplate: false,
            completed: false,
            priority: priority,
            isOngoing: false
        )
        
        // Add task to data store
        dataStore.addTaskEvent(taskEvent, for: date)
        
        // Calculate notification time
        let notificationTime: Date
        switch notifyOption {
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
        
        // If it's a template, add it to the baby's templates
        if isTemplate {
            var updatedBaby = dataStore.baby
            // Add the task template (use a method to add task templates)
            // This would need to be implemented in the Baby model
            
            dataStore.baby = updatedBaby
        }
        
        presentationMode.wrappedValue.dismiss()
    }
    
    private func scheduleTaskNotification(_ task: TaskEvent, at time: Date) {
        // Only schedule if it's in the future
        if time > Date() {
            let content = UNMutableNotificationContent()
            content.title = "Task Reminder: \(task.title)"
            content.body = "Task scheduled to start at \(formatTime(task.date))"
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
