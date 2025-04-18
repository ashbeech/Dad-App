//
//  AddFeedView.swift
//  Dad App
//
//  Created by Ashley Davison on 06/03/2025.
//

import SwiftUI
import Combine

struct AddFeedView: View {
    @EnvironmentObject var dataStore: DataStore
    @Environment(\.presentationMode) var presentationMode
    
    let date: Date
    let initialTime: Date
    
    @State private var amount: Double = 180
    @State private var breastMilkPercentage: Double = 0
    @State private var formulaPercentage: Double = 100
    @State private var feedTime: Date
    @State private var prepTime: Date
    @State private var notes: String = ""
    
    @State private var offset: CGFloat = 0
    @State private var buttonScale: CGFloat = 1.0
    
    init(date: Date, initialTime: Date = Date()) {
        self.date = date
        self.initialTime = initialTime
        
        // Initialize with the provided initialTime
        let calendar = Calendar.current
        
        // Extract year, month, day from date and hour, minute from initialTime
        var dateComponents = calendar.dateComponents([.year, .month, .day], from: date)
        let timeComponents = calendar.dateComponents([.hour, .minute], from: initialTime)
        
        // Combine them
        dateComponents.hour = timeComponents.hour
        dateComponents.minute = timeComponents.minute
        
        let combinedDate = calendar.date(from: dateComponents) ?? initialTime
        _feedTime = State(initialValue: combinedDate)
        
        // Default prep time is 1 hour before feed time
        _prepTime = State(initialValue: combinedDate.addingTimeInterval(-3600))
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
            
            Button(action: {
                // Animation for button press
                withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                    buttonScale = 0.95
                }
                
                // Delay to show the button press effect
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                        buttonScale = 1.0
                    }
                    // Delay to allow animation to complete before saving
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.0) {
                        saveEvent()
                    }
                }
            }) {
                Text("Save Feed Event")
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                    .scaleEffect(buttonScale)
            }
            .buttonStyle(PlainButtonStyle())
            .padding()
        }
    }
    
    private func saveEvent() {
        let feedEvent = FeedEvent(
            date: feedTime,
            amount: amount,
            breastMilkPercentage: breastMilkPercentage,
            formulaPercentage: formulaPercentage,
            preparationTime: prepTime,
            notes: notes,
            isTemplate: false
        )
        
        // Add event for the day
        dataStore.addFeedEvent(feedEvent, for: date)
        
        // Ensure we dismiss the entire view
        DispatchQueue.main.async {
            presentationMode.wrappedValue.dismiss()
        }
    }
}
