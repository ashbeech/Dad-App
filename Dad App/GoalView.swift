//
//  GoalView.swift
//  Dad App
//
//  Created by Ash Beech on 02/04/2025.
//

import SwiftUI

struct GoalView: View {
    @EnvironmentObject var dataStore: DataStore
    @Environment(\.presentationMode) var presentationMode
    
    @State private var goalText: String = ""
    @State private var textEditorHeight: CGFloat = 40
    @State private var goalDeadline: Date = Date().addingTimeInterval(24 * 60 * 60) // Default: 1 day from now
    
    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            
            Text("What do you want to achieve?")
                .font(.headline)
                .padding(.bottom, 10)
            
            TextEditor(text: $goalText)
                .padding(10)
                .frame(height: max(40, textEditorHeight))
                .background(Color(UIColor.systemGray6))
                .cornerRadius(8)
                .padding(.horizontal, 20)
                .onChange(of: goalText) { _, newText in
                    // Adjust height based on text content
                    let estimatedHeight = estimateTextHeight(text: newText)
                    withAnimation {
                        textEditorHeight = min(max(40, estimatedHeight), 200) // Limit to max 200 height
                    }
                }
            
            DatePicker("Goal Deadline", selection: $goalDeadline, displayedComponents: [.date, .hourAndMinute])
                .padding(.horizontal, 20)
            
            Button(action: {
                // Save goal to data store
                saveGoal()
                
                // Dismiss the view
                presentationMode.wrappedValue.dismiss()
            }) {
                Text("Let's go")
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(goalText.isEmpty ? Color.gray : Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }
            .padding(.horizontal, 20)
            .disabled(goalText.isEmpty)
            
            Spacer()
        }
        .padding()
    }
    
    // Helper function to estimate text height
    private func estimateTextHeight(text: String) -> CGFloat {
        let font = UIFont.preferredFont(forTextStyle: .body)
        let attributes = [NSAttributedString.Key.font: font]
        let size = CGSize(width: UIScreen.main.bounds.width - 60, height: CGFloat.greatestFiniteMagnitude)
        let estimatedFrame = text.boundingRect(with: size, options: .usesLineFragmentOrigin, attributes: attributes, context: nil)
        return estimatedFrame.height + 30 // Add padding
    }
    
    // Helper function to save the goal to the data store
    private func saveGoal() {
        guard !goalText.isEmpty else { return }
        
        // Create a new goal
        let goal = GoalEvent(
            date: goalDeadline,
            title: goalText
        )
        
        // Get today's date for placement in the calendar
        let todayDate = Date()
        
        // Add goal to datastore directly
        dataStore.addGoalEvent(goal, for: todayDate)
    }
}
