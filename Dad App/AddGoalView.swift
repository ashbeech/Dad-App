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
    let initialTime: Date
    
    @State private var title: String = ""
    @State private var deadline: Date
    
    // For keyboard avoidance
    @State private var keyboardHeight: CGFloat = 0
    
    init(date: Date, initialTime: Date = Date()) {
        self.date = date
        self.initialTime = initialTime
        
        // Set deadline to the provided initialTime (which is when the user tapped)
        _deadline = State(initialValue: initialTime)
    }
    
    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(spacing: 0) {
                    Form {
                        Section(header: Text("Goal Details")) {
                            TextField("What do you want to achieve?", text: $title)
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
                        }
                        
                        Section(header: Text("Timing")) {
                            DatePicker("Deadline", selection: $deadline, displayedComponents: [.date, .hourAndMinute])
                                .onChange(of: deadline) { _, newValue in
                                    // Validate time is within wake and bedtime
                                    let startDay = Calendar.current.startOfDay(for: newValue)
                                    let (validDeadline, _) = dataStore.validateEventTimes(
                                        startTime: newValue,
                                        endTime: newValue.addingTimeInterval(60),
                                        for: startDay
                                    )
                                    if validDeadline != newValue {
                                        deadline = validDeadline
                                    }
                                }
                        }
                        
                        Button(action: saveGoal) {
                            Text("Save Goal")
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(title.isEmpty ? Color.gray : Color.orange)
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
    
    private func saveGoal() {
        guard !title.isEmpty else { return }
        
        // Create a new goal
        let goal = GoalEvent(
            date: deadline,
            title: title
        )
        
        // Add goal to datastore
        dataStore.addGoalEvent(goal, for: date)
        
        // Provide haptic feedback for successful save
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
        
        // Dismiss the view
        presentationMode.wrappedValue.dismiss()
    }
}
