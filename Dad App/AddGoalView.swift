//
//  AddGoalView.swift
//  Dad App
//
//  Created by Ashley Davison on 02/04/2025.
//

import SwiftUI

struct AddGoalView: View {
    @EnvironmentObject var dataStore: DataStore
    @Environment(\.presentationMode) var presentationMode
    
    let date: Date
    
    @State private var goalText: String = ""
    @State private var deadline: Date
    @State private var includeDeadline: Bool = true  // Default to true for Phase 1
    @State private var isGenerating: Bool = false
    @State private var generatedResponse: TaskBreakdownResponse?
    @State private var showError: Bool = false
    @State private var errorMessage: String = ""
    
    init(date: Date) {
        self.date = date
        // Default deadline: 30 days from now
        _deadline = State(initialValue: Calendar.current.date(byAdding: .day, value: 30, to: date) ?? date)
    }
    
    var body: some View {
        NavigationView {
            Form {
                // Goal Input Section
                Section(header: Text("What do you want to achieve?")) {
                    TextField("e.g., Launch a SaaS product, Learn to play guitar", text: $goalText, axis: .vertical)
                        .lineLimit(3...6)
                        .font(.body)
                }
                
                // Deadline Section
                Section {
                    Toggle("Set a deadline", isOn: $includeDeadline)
                    
                    if includeDeadline {
                        DatePicker("Complete by", selection: $deadline, in: Date()..., displayedComponents: [.date])
                    }
                } footer: {
                    Text("A deadline helps the AI schedule tasks across days and weeks.")
                        .font(.caption)
                }
                
                // Generate Button
                Section {
                    Button(action: generatePlan) {
                        HStack {
                            if isGenerating {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle())
                                Text("Creating your plan...")
                            } else {
                                Image(systemName: "sparkles")
                                Text("Generate Plan")
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(goalText.isEmpty || isGenerating ? Color.gray : Color.indigo)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .disabled(goalText.isEmpty || isGenerating)
                }
                
                // Preview Generated Plan
                if let response = generatedResponse {
                    // Milestones Section
                    if let milestones = response.milestones, !milestones.isEmpty {
                        Section(header: Text("Milestones (\(milestones.count))")) {
                            ForEach(milestones.indices, id: \.self) { index in
                                HStack {
                                    Image(systemName: "flag.fill")
                                        .foregroundColor(.orange)
                                        .frame(width: 25)
                                    VStack(alignment: .leading) {
                                        Text(milestones[index].title)
                                            .font(.body)
                                            .fontWeight(.medium)
                                        Text("Target: \(formatDate(milestones[index].targetDate))")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }
                            }
                        }
                    }
                    
                    // Tasks Section
                    Section(header: Text("Tasks (\(response.tasks.count))")) {
                        ForEach(response.tasks.indices, id: \.self) { index in
                            let task = response.tasks[index]
                            HStack {
                                Text("\(index + 1).")
                                    .foregroundColor(.secondary)
                                    .frame(width: 25)
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(task.title)
                                        .font(.body)
                                    HStack {
                                        if let scheduledDate = task.scheduledDate {
                                            Text(formatDate(scheduledDate))
                                                .font(.caption)
                                                .foregroundColor(.blue)
                                        }
                                        if let startTime = task.scheduledStartTime {
                                            Text("@ \(startTime)")
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }
                                        Text("~\(task.estimatedMinutes) min")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }
                            }
                        }
                        
                        // Save All Button
                        Button(action: saveGoalAndPlan) {
                            HStack {
                                Image(systemName: "checkmark.circle.fill")
                                Text("Save Goal & Plan")
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.green)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                        }
                        .buttonStyle(PlainButtonStyle())
                        
                        // Regenerate Button
                        Button(action: generatePlan) {
                            HStack {
                                Image(systemName: "arrow.clockwise")
                                Text("Regenerate")
                            }
                            .foregroundColor(.indigo)
                        }
                    }
                }
            }
            .navigationTitle("New Goal")
            .navigationBarTitleDisplayMode(.inline)
            .alert("Error", isPresented: $showError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage)
            }
        }
    }
    
    private func formatDate(_ dateString: String) -> String {
        let inputFormatter = ISO8601DateFormatter()
        inputFormatter.formatOptions = [.withFullDate]
        
        guard let date = inputFormatter.date(from: dateString) else {
            return dateString
        }
        
        let outputFormatter = DateFormatter()
        outputFormatter.dateStyle = .medium
        return outputFormatter.string(from: date)
    }
    
    private func generatePlan() {
        guard !goalText.isEmpty else { return }
        
        isGenerating = true
        generatedResponse = nil
        
        Task {
            do {
                // Phase 3: Pass execution profile if we have learned patterns
                let response = try await AIService.shared.breakdownGoal(
                    goal: goalText,
                    deadline: includeDeadline ? deadline : nil,
                    preferences: dataStore.userPreferences,
                    executionProfile: dataStore.executionProfile
                )
                
                await MainActor.run {
                    generatedResponse = response
                    isGenerating = false
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    showError = true
                    isGenerating = false
                }
            }
        }
    }
    
    private func saveGoalAndPlan() {
        guard let response = generatedResponse else { return }
        
        let goalId = UUID()
        var milestoneIds: [UUID] = []
        var taskIds: [UUID] = []
        
        // Create a mapping from milestone index to UUID
        var milestoneIndexToId: [Int: UUID] = [:]
        
        // Phase 1: Create milestones first
        if let generatedMilestones = response.milestones {
            for (index, genMilestone) in generatedMilestones.enumerated() {
                let milestoneId = UUID()
                milestoneIds.append(milestoneId)
                milestoneIndexToId[index] = milestoneId
                
                let milestone = genMilestone.toMilestone(goalId: goalId)
                var mutableMilestone = milestone
                mutableMilestone.id = milestoneId
                
                dataStore.addMilestone(mutableMilestone)
            }
        }
        
        // Create tasks with AI-scheduled dates
        for (index, generatedTask) in response.tasks.enumerated() {
            let taskId = UUID()
            taskIds.append(taskId)
            
            // Get the scheduled date/time from the AI response
            let scheduledDateTime = generatedTask.getScheduledDateTime(fallbackDate: date)
            let taskEndTime = scheduledDateTime.addingTimeInterval(TimeInterval(generatedTask.estimatedMinutes * 60))
            
            // Link to milestone if specified
            let milestoneId: UUID? = {
                if let milestoneIndex = generatedTask.milestoneIndex {
                    return milestoneIndexToId[milestoneIndex]
                }
                return nil
            }()
            
            let taskEvent = TaskEvent(
                id: taskId,
                date: scheduledDateTime,
                title: generatedTask.title,
                endTime: taskEndTime,
                notes: "Generated from goal: \(goalText)",
                parentGoalId: goalId,
                orderInGoal: index + 1,
                milestoneId: milestoneId,
                scheduledDate: generatedTask.getScheduledDate(),
                estimatedMinutes: generatedTask.estimatedMinutes
            )
            
            // Add task to the date it's scheduled for
            let taskDate = generatedTask.getScheduledDate() ?? date
            dataStore.addTaskEvent(taskEvent, for: taskDate)
        }
        
        // Create and save the goal
        let goal = GoalEvent(
            id: goalId,
            date: date,
            deadline: includeDeadline ? deadline : nil,
            title: goalText,
            taskIds: taskIds,
            milestoneIds: milestoneIds
        )
        
        dataStore.addGoalEvent(goal, for: date)
        
        // Haptic feedback
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
        
        presentationMode.wrappedValue.dismiss()
    }
}
