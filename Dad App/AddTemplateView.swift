//
//  AddTemplateView.swift
//  Dad App
//
//  Created by Ash Beech on 06/03/2025.
//

import SwiftUI

struct AddTemplateView: View {
    let templateType: EventType
    
    var body: some View {
        Group {
            if templateType == .feed {
                AddFeedTemplateView()
            } else {
                AddSleepTemplateView()
            }
        }
        .navigationTitle("Add \(templateType.rawValue) Template")
    }
}

struct AddFeedTemplateView: View {
    @EnvironmentObject var dataStore: DataStore
    @Environment(\.presentationMode) var presentationMode
    
    @State private var amount: Double = 180
    @State private var breastMilkPercentage: Double = 0
    @State private var formulaPercentage: Double = 100
    @State private var feedTime: Date = Date()
    @State private var prepTime: Date = Date().addingTimeInterval(-3600)
    @State private var notes: String = ""
    
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
                TextField("Any special notes", text: $notes)
            }
            
            Button(action: saveTemplate) {
                Text("Save Template")
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }
            .buttonStyle(PlainButtonStyle())
            .padding()
        }
    }
    
    private func saveTemplate() {
        let template = FeedEvent(
            date: feedTime,
            amount: amount,
            breastMilkPercentage: breastMilkPercentage,
            formulaPercentage: formulaPercentage,
            preparationTime: prepTime,
            notes: notes,
            isTemplate: true
        )
        
        var updatedBaby = dataStore.baby
        updatedBaby.feedTemplates.append(template)
        dataStore.baby = updatedBaby
        
        presentationMode.wrappedValue.dismiss()
    }
}

struct AddSleepTemplateView: View {
    @EnvironmentObject var dataStore: DataStore
    @Environment(\.presentationMode) var presentationMode
    
    @State private var sleepType: SleepType = .nap
    @State private var startTime: Date = Date()
    @State private var endTime: Date = Date().addingTimeInterval(30 * 60)
    @State private var notes: String = ""
    
    var body: some View {
        Form {
            Section(header: Text("Sleep Type")) {
                Picker("Type", selection: $sleepType) {
                    Text("Nap").tag(SleepType.nap)
                    Text("Bedtime").tag(SleepType.bedtime)
                }
                .pickerStyle(SegmentedPickerStyle())
            }
            
            Section(header: Text("Timing")) {
                DatePicker("Start Time", selection: $startTime, displayedComponents: .hourAndMinute)
                DatePicker("End Time", selection: $endTime, displayedComponents: .hourAndMinute)
                    .onChange(of: startTime) { _, newValue in
                        // Ensure end time is always after start time
                        if endTime <= newValue {
                            endTime = newValue.addingTimeInterval(30 * 60)
                        }
                    }
            }
            
            Section(header: Text("Notes")) {
                TextField("Any special notes", text: $notes)
            }
            
            Button(action: saveTemplate) {
                Text("Save Template")
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.purple)
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }
            .buttonStyle(PlainButtonStyle())
            .padding()
        }
    }
    
    private func saveTemplate() {
        let template = SleepEvent(
            date: startTime,
            sleepType: sleepType,
            endTime: endTime,
            notes: notes,
            isTemplate: true
        )
        
        var updatedBaby = dataStore.baby
        updatedBaby.sleepTemplates.append(template)
        dataStore.baby = updatedBaby
        
        presentationMode.wrappedValue.dismiss()
    }
}
