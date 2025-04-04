//
//  EditFeedView.swift
//  Dad App
//
//  Created by Ashley Davison on 06/03/2025.
//

import SwiftUI

struct EditFeedView: View {
    @EnvironmentObject var dataStore: DataStore
    @Environment(\.presentationMode) var presentationMode
    
    let feedEvent: FeedEvent
    let date: Date
    
    @State private var amount: Double
    @State private var breastMilkPercentage: Double
    @State private var formulaPercentage: Double
    @State private var feedTime: Date
    @State private var prepTime: Date
    @State private var notes: String
    
    @State private var offset: CGFloat = 0
    @State private var updateButtonScale: CGFloat = 1.0
    @State private var deleteButtonScale: CGFloat = 1.0
    
    init(feedEvent: FeedEvent, date: Date) {
        self.feedEvent = feedEvent
        self.date = date
        
        _amount = State(initialValue: feedEvent.amount)
        _breastMilkPercentage = State(initialValue: feedEvent.breastMilkPercentage)
        _formulaPercentage = State(initialValue: feedEvent.formulaPercentage)
        _feedTime = State(initialValue: feedEvent.date)
        _prepTime = State(initialValue: feedEvent.preparationTime)
        _notes = State(initialValue: feedEvent.notes)
    }
    
    var body: some View {
        Form {
            Section(header: Text("Feed Details")) {
                Stepper(value: $amount, in: 10...500, step: 10) {
                    HStack {
                        Text("Amount:")
                        Spacer()
                        Text("\(Int(amount)) ml")
                    }
                }
                
                VStack(alignment: .leading) {
                    HStack {
                        Text("Breast Milk: \(Int(breastMilkPercentage))%")
                        Spacer()
                        Text("Formula: \(Int(formulaPercentage))%")
                    }
                    
                    Slider(value: $breastMilkPercentage, in: 0...100, step: 5) {
                        Text("Breast Milk Percentage")
                    }
                    .onChange(of: breastMilkPercentage) { _, newValue in
                        formulaPercentage = 100 - newValue
                    }
                }
            }
            
            Section(header: Text("Timing")) {
                DatePicker("Feed Time", selection: $feedTime, displayedComponents: .hourAndMinute)
                DatePicker("Preparation Time", selection: $prepTime, displayedComponents: .hourAndMinute)
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
                Button(action: {
                    // Animation for button press
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                        updateButtonScale = 0.95
                    }
                    
                    // Delay to show the button press effect
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                            updateButtonScale = 1.0
                        }
                        
                        // Delay to allow animation to complete before saving
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.0) {
                            saveEvent()
                        }
                    }
                }) {
                    Text("Update")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                        .scaleEffect(updateButtonScale)
                }
                .buttonStyle(PlainButtonStyle())
                
                Button(action: {
                    // Animation for button press
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                        deleteButtonScale = 0.95
                    }
                    
                    // Delay to show the button press effect
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                            deleteButtonScale = 1.0
                        }
                        
                        // Delay to allow animation to complete before deleting
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.0) {
                            deleteEvent()
                        }
                    }
                }) {
                    Text("Delete")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.red)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                        .scaleEffect(deleteButtonScale)
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding()
        }
        .offset(y: offset)
    }
    
    private func saveEvent() {
        let updatedEvent = FeedEvent(
            id: feedEvent.id,
            date: feedTime,
            amount: amount,
            breastMilkPercentage: breastMilkPercentage,
            formulaPercentage: formulaPercentage,
            preparationTime: prepTime,
            notes: notes,
            isTemplate: false
        )
        
        dataStore.updateFeedEvent(updatedEvent, for: date)
        
        // Ensure we dismiss the entire edit view
        DispatchQueue.main.async {
            presentationMode.wrappedValue.dismiss()
            // Use NotificationCenter to notify parent views to dismiss as well
            NotificationCenter.default.post(name: NSNotification.Name("DismissEditView"), object: nil)
        }
    }
    
    private func deleteEvent() {
        dataStore.deleteFeedEvent(feedEvent, for: date)
        
        // Ensure we dismiss the entire edit view
        DispatchQueue.main.async {
            presentationMode.wrappedValue.dismiss()
            // Use NotificationCenter to notify parent views to dismiss as well
            NotificationCenter.default.post(name: NSNotification.Name("DismissEditView"), object: nil)
        }
    }
}
