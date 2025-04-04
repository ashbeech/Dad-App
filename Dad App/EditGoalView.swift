//
//  EditGoalView.swift
//  Dad App
//
//  Created by Ashley Davison on 02/04/2025.
//

import SwiftUI

struct EditGoalView: View {
    @EnvironmentObject var dataStore: DataStore
    @Environment(\.presentationMode) var presentationMode
    
    let goalEvent: GoalEvent
    let date: Date
    
    @State private var title: String
    @State private var deadline: Date
    @State private var showDeleteConfirmation: Bool = false
    
    init(goalEvent: GoalEvent, date: Date) {
        self.goalEvent = goalEvent
        self.date = date
        
        _title = State(initialValue: goalEvent.title)
        _deadline = State(initialValue: goalEvent.date)
    }
    
    var body: some View {
        Form {
            Section(header: Text("Goal Details")) {
                TextField("Goal", text: $title)
                    .font(.body)
                    .foregroundColor(.primary)
                    .padding(.vertical, 4)
                
                DatePicker("Deadline", selection: $deadline, displayedComponents: [.date, .hourAndMinute])
            }
            
            HStack {
                Button(action: saveGoal) {
                    Text("Update")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(title.isEmpty ? Color.gray : Color.orange)
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
                title: Text("Delete Goal"),
                message: Text("Are you sure you want to delete this goal?"),
                primaryButton: .destructive(Text("Delete")) {
                    deleteGoal()
                },
                secondaryButton: .cancel()
            )
        }
    }
    
    private func saveGoal() {
        let updatedGoal = GoalEvent(
            id: goalEvent.id,
            date: deadline,
            title: title
        )
        
        // Use the dataStore directly (fix for compiler error)
        dataStore.updateGoalEvent(updatedGoal, for: date)
        presentationMode.wrappedValue.dismiss()
    }
    
    private func deleteGoal() {
        // Use the dataStore directly (fix for compiler error)
        dataStore.deleteGoalEvent(goalEvent, for: date)
        
        // Close the form
        presentationMode.wrappedValue.dismiss()
        
        // Notify parent views to dismiss as well
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            NotificationCenter.default.post(name: NSNotification.Name("DismissEditView"), object: nil)
        }
    }
}
