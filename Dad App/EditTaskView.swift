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
    @State private var priority: TaskPriority
    @State private var startTime: Date
    @State private var endTime: Date
    @State private var notes: String
    @State private var isOngoing: Bool
    @State private var completed: Bool
    @State private var showDeleteConfirmation: Bool = false
    
    init(taskEvent: TaskEvent, date: Date) {
        self.taskEvent = taskEvent
        self.date = date
        
        _title = State(initialValue: taskEvent.title)
        _priority = State(initialValue: taskEvent.priority)
        _startTime = State(initialValue: taskEvent.date)
        _endTime = State(initialValue: taskEvent.endTime)
        _notes = State(initialValue: taskEvent.notes)
        _isOngoing = State(initialValue: taskEvent.isOngoing)
        _completed = State(initialValue: taskEvent.completed)
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
                
                Toggle("Completed", isOn: $completed)
                    .toggleStyle(SwitchToggleStyle(tint: .green))
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
                
                Toggle("Track in real-time", isOn: $isOngoing)
                    .toggleStyle(SwitchToggleStyle(tint: .green))
            }
            
            Section(header: Text("Notes")) {
                TextField("Any special notes", text: $notes)
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
    
    private func saveTask() {
        // Create updated task
        let updatedTask = TaskEvent(
            id: taskEvent.id,
            date: startTime,
            title: title,
            endTime: endTime,
            notes: notes,
            isTemplate: taskEvent.isTemplate,
            completed: completed,
            priority: priority,
            isOngoing: isOngoing
        )
        
        // Update in data store
        dataStore.updateTaskEvent(updatedTask, for: date)
        
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
