//
//  EditTaskView.swift
//  Dad App
//

import SwiftUI

struct EditTaskView: View {
    @EnvironmentObject var dataStore: DataStore
    @Environment(\.presentationMode) var presentationMode
    
    let taskEvent: TaskEvent
    let date: Date
    
    @State private var title: String
    @State private var startTime: Date
    @State private var endTime: Date
    @State private var notes: String
    @State private var isOngoing: Bool
    @State private var completed: Bool
    @State private var showDeleteConfirmation: Bool = false
    @State private var hasEndTime: Bool
    @State private var titleModifiedByUser: Bool = false // Track if user modified the title
    
    // For keyboard avoidance
    @State private var keyboardHeight: CGFloat = 0
    
    init(taskEvent: TaskEvent, date: Date) {
        self.taskEvent = taskEvent
        self.date = date
        
        // Always initialize with original title, not past tense version
        _title = State(initialValue: taskEvent.title)
        _startTime = State(initialValue: taskEvent.date)
        _endTime = State(initialValue: taskEvent.endTime)
        _notes = State(initialValue: taskEvent.notes)
        _isOngoing = State(initialValue: taskEvent.isOngoing)
        _completed = State(initialValue: taskEvent.completed)
        _hasEndTime = State(initialValue: taskEvent.hasEndTime)
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
                                .onChange(of: title) { _, newValue in
                                    // If title changed, mark as modified by user
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
                            
                            Toggle("Add duration", isOn: $hasEndTime)
                                .toggleStyle(SwitchToggleStyle(tint: .green))
                                .onChange(of: hasEndTime) { _, newValue in
                                    if newValue {
                                        // When toggling duration on, ensure end time is 1 hour after start
                                        updateEndTimeToOneHourLater()
                                    }
                                }
                            
                            if hasEndTime {
                                // Time-only picker for end time
                                DatePicker("End Time", selection: $endTime, displayedComponents: .hourAndMinute)
                                    .onChange(of: endTime) { _, newValue in
                                        // Ensure end time stays on same day
                                        ensureEndTimeOnSameDay()
                                        
                                        // Validate time is within wake and bedtime
                                        let startDay = Calendar.current.startOfDay(for: startTime)
                                        let (_, validEnd) = dataStore.validateEventTimes(startTime: startTime, endTime: endTime, for: startDay)
                                        if validEnd != newValue {
                                            endTime = validEnd
                                        }
                                    }
                            }
                            
                            Toggle("Track in real-time", isOn: $isOngoing)
                                .toggleStyle(SwitchToggleStyle(tint: .green))
                                .disabled(!hasEndTime)
                                .opacity(hasEndTime ? 1.0 : 0.5)
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
                        
                        HStack {
                            Button(action: saveTask) {
                                Text("Update")
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(title.isEmpty ? Color.gray : Color.green)
                                    .foregroundColor(.white)
                                    .cornerRadius(10)
                            }
                            .buttonStyle(PlainButtonStyle())
                            .disabled(title.isEmpty)
                            
                            Button(action: {
                                showDeleteConfirmation = true
                            }) {
                                Text("Delete")
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Color.red)
                                    .foregroundColor(.white)
                                    .cornerRadius(10)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                        .padding()
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
        .alert(isPresented: $showDeleteConfirmation) {
            Alert(
                title: Text("Delete Task"),
                message: Text("Are you sure you want to delete this task?"),
                primaryButton: .destructive(Text("Delete")) {
                    deleteTask()
                },
                secondaryButton: .cancel()
            )
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
        // If has no end time, use start time + 1 minute as end time
        let finalEndTime = hasEndTime ? endTime : startTime.addingTimeInterval(1 * 60)
        
        // Create updated task - past tense title will be generated in DataStore.updateTaskEvent
        let updatedTask = TaskEvent(
            id: taskEvent.id,
            date: startTime,
            title: title, // Store original title
            endTime: finalEndTime,
            notes: notes,
            isTemplate: false,
            completed: completed,
            isOngoing: hasEndTime ? isOngoing : false,
            hasEndTime: hasEndTime
        )
        
        // Determine which date to use (the day of the start time)
        let calendar = Calendar.current
        let taskDate = calendar.startOfDay(for: startTime)
        
        // If the date has changed, we need to move the task
        if calendar.startOfDay(for: taskEvent.date) != taskDate {
            // Delete from old date
            dataStore.deleteTaskEvent(taskEvent, for: date)
            
            // Add to new date
            dataStore.addTaskEvent(updatedTask, for: taskDate)
        } else {
            // Update in existing date
            dataStore.updateTaskEvent(updatedTask, for: taskDate)
        }
        
        presentationMode.wrappedValue.dismiss()
    }
    
    private func deleteTask() {
        // Delete from data store
        dataStore.deleteTaskEvent(taskEvent, for: date)
        
        // Close the form
        presentationMode.wrappedValue.dismiss()
        
        // Notify parent views to dismiss as well
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            NotificationCenter.default.post(name: NSNotification.Name("DismissEditView"), object: nil)
        }
    }
}
